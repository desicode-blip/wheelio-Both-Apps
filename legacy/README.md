# Earlier Flutter implementation

This folder preserves the earlier Flutter approach for reference. Active development lives in `apps/web`, `apps/ios` and the reserved `apps/android` directory at the repository root.

- `apps/customer`: Flutter customer screens, mock backend and logic tests.
- `packages/wheelio_ui`: Flutter design system. The customer app's relative package dependency is preserved.
- `tool/bootstrap_customer.sh`: optional legacy setup, run from the repository root with `bash legacy/tool/bootstrap_customer.sh` after installing Flutter.

No archived source was discarded during the platform restructure. Generated Xcode and web build files are ignored by Git.
