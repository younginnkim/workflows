# stage3_tasgen/tasbase.py
###################################################################################
# @@@LICENSE
#
#   Copyright (c) 2024 by LG Electronics Inc.
#
#   All rights reserved. No part of this work may be reproduced, stored in a
#   retrieval system, or transmitted by any means without prior written
#   permission of LG Electronics Inc.
#
# LICENSE@@@
####################################################################################
"""Generic, app-agnostic TAS base for webOS Flutter apps (SHIPPED runtime artifact).

Runs inside the `automation-tests` framework (imports webos.utils.*); it is NOT
importable in the tas-tool venv and is validated by AST only. Subclasses fill the
meta class-attrs (FLUTTER_APP_ID / SAM_APP_ID / FLAG_FILE / JIRA_ID). Encapsulates
find / key / getProperty-parse / assert primitives so generated per-TC scripts stay
thin. The Map.toString parser uses the same strategy as stage3_tasgen/propparse.py
(inline here; that module is the unit-tested twin).
"""
from webos.utils.Flutter import Flutter
from webos.utils.Sam import Sam
from webos.utils.LunaSend import LunaSend
from webos.utils.pytell.input_generator_service import InputGeneratorService
from webos.utils.zephyr.ZephyrTest import ZephyrTest
from webos.utils.utils import wait_for_time

_KEYNAME = {"OK": "enter", "UP": "up", "DOWN": "down", "LEFT": "left",
            "RIGHT": "right", "BACK": "back", "HOME": "home"}


class TasFlutterBase(ZephyrTest):
    FLUTTER_APP_ID = None
    SAM_APP_ID = None
    FLAG_FILE = None
    JIRA_ID = None
    test_name = "TasFlutterBase"

    def __init__(self):
        ZephyrTest.__init__(self, self.test_name, author="younginn.kim")
        if self.JIRA_ID:
            self.set_zephyr_key(self.JIRA_ID)

    def _run(self, **kwargs):
        self.zephyr.step()
        self._cmd = self.get_command_line()
        self._sam = Sam(self._cmd)
        self._luna = LunaSend(cmd=self._cmd)
        self._input = InputGeneratorService(self._cmd)
        self.log_info("[START] {0}".format(self.test_name))
        try:
            app_info = self._luna.send(
                "com.webos.service.applicationmanager", "getAppInfo",
                params={"id": self.SAM_APP_ID})
            app_type = app_info["appInfo"]["type"]
            self.log_info("App type = {0}".format(app_type))
            # flutter-webos 앱은 SAM에 type="native"로 등록되므로 app_type 문자열로 분기하면
            # 안 됨 → 서브클래스가 run_flutter_test를 오버라이드했는지로 flutter 테스트를 판별.
            if type(self).run_flutter_test is not __class__.run_flutter_test:
                self._flutter = Flutter(cmd=self._cmd)
                self._flutter.checkTestEnviroment(filename=self.FLAG_FILE)
                self._check_flutter_service()
                self.run_flutter_test()
            else:
                self.run_test()
        finally:
            self.log_info("[END] {0}".format(self.test_name))

    def _check_flutter_service(self):
        """Ping the Flutter TAS service; relaunch the app generically if it is down."""
        response = self._luna.send(self.FLUTTER_APP_ID, "com/palm/luna/private/ping", {}, timeout=5)
        if not response or not response.get("returnValue", False):
            self.log_info("Flutter service {0} not running; relaunching {1}".format(
                self.FLUTTER_APP_ID, self.SAM_APP_ID))
            self._sam.launch(self.SAM_APP_ID)
            wait_for_time(5)

    # ── low-level ───────────────────────────────────────────────
    def find(self, typeName=None, by_text=None, by_key=None, index=None):
        if by_text is not None:
            res = self._flutter.findByText(by_text)
        elif by_key is not None:
            res = self._flutter.findByKey(by_key)
        else:
            res = self._flutter.findByTypeName(typeName)
        if index is not None:
            self._flutter.findAt(index)
        return res

    def focus(self, typeName=None, by_text=None, by_key=None, index=None):
        self.find(typeName, by_text, by_key, index)
        self._flutter.setFocus()

    def send_key(self, key):
        self._input.press_key(_KEYNAME[key])

    def tap(self):
        self._flutter.tap()

    def wait(self, seconds=1):
        wait_for_time(seconds)

    def get_property(self):
        response = self._flutter.getProperty()
        if "properties" not in response:
            return []
        results = []
        for prop in response["properties"]:
            prop = prop[1:-1]
            item = {}
            for data in prop.split(", "):
                kv = data.split(": ", 1)
                if len(kv) > 1:
                    item[kv[0]] = kv[1]
            results.append(item)
        return results

    # ── assertions (primitives) ─────────────────────────────────
    def assert_widget_present(self, typeName, where=None):
        self.find(typeName)
        results = self.get_property()
        if where:
            ok = any(all(r.get(k) == v for k, v in where.items()) for r in results)
        else:
            ok = len(results) > 0
        self.assertTrue(ok, "ERROR: {0} not present (where={1})".format(typeName, where))

    def assert_any_present(self, options):
        for opt in options:
            self.find(opt["typeName"])
            results = self.get_property()
            where = opt.get("where")
            if where:
                if any(all(r.get(k) == v for k, v in where.items()) for r in results):
                    return
            elif len(results) > 0:
                return
        self.assertTrue(False, "ERROR: none of {0} present".format(options))

    def assert_property(self, typeName, key, op, value, group=None):
        self.find(typeName)
        results = self.get_property()
        if group is not None:
            results = [r for r in results if r.get("group_label") == group]
        actual = None
        for r in results:
            if key in r:
                actual = r[key]
                break
        ok = self._compare(actual, op, value)
        self.assertTrue(ok, "ERROR: {0}.{1} {2} {3} (actual={4})".format(typeName, key, op, value, actual))

    def assert_app_launch(self, appId):
        fg = self._sam.getForegroundAppInfo().get("appId")
        self.assertEqual(appId, fg, "ERROR: {0} not foreground (actual={1})".format(appId, fg))

    @staticmethod
    def _compare(actual, op, value):
        if actual is None:
            return False
        try:
            a, b = int(actual), int(value)
        except (TypeError, ValueError):
            a, b = str(actual), str(value)
        return {"==": a == b, "!=": a != b, ">": a > b, ">=": a >= b,
                "<": a < b, "<=": a <= b}[op]

    def run_flutter_test(self):
        raise NotImplementedError

    def run_test(self):
        raise NotImplementedError
