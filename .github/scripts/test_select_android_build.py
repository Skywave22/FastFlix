import unittest

from select_android_build import REQUIRED_SECRETS, select_mode


class SelectAndroidBuildTest(unittest.TestCase):
    def test_publishing_always_requires_a_release_build(self):
        self.assertEqual(select_mode("push", "tag", "", {}), "release")
        self.assertEqual(
            select_mode("workflow_dispatch", "branch", "v1.2.3", {}), "release"
        )
        # Even an invalid non-empty tag must never silently publish a preview.
        self.assertEqual(
            select_mode("workflow_dispatch", "branch", " ", {}), "release"
        )

    def test_complete_secrets_enable_signed_artifacts(self):
        secrets = {name: "configured" for name in REQUIRED_SECRETS}
        self.assertEqual(select_mode("push", "branch", "", secrets), "release")
        self.assertEqual(
            select_mode("workflow_dispatch", "branch", "", secrets), "release"
        )

    def test_artifact_only_build_falls_back_if_any_secret_is_missing(self):
        self.assertEqual(select_mode("push", "branch", "", {}), "preview")
        for missing in REQUIRED_SECRETS:
            with self.subTest(missing=missing):
                secrets = {name: "configured" for name in REQUIRED_SECRETS}
                secrets[missing] = " \n "
                self.assertEqual(
                    select_mode("push", "branch", "", secrets), "preview"
                )

    def test_manual_artifact_only_build_can_use_preview(self):
        self.assertEqual(
            select_mode("workflow_dispatch", "branch", "", {}), "preview"
        )


if __name__ == "__main__":
    unittest.main()
