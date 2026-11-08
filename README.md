# pmes_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Offline field and financial data

The mobile app stores projects, field progress logs, and financial transactions
in a local SQLite database (`pmes_mobile.db`). Field logs are queued through
`FieldLogRepository.writeFieldLog`. Financial records are queued through
`FinancialTransactionRepository.writeFinancialTransaction`, then immediately
attempted against the remote API. If the server accepts a financial record, the
local record is marked synced; if not, it remains queued with a persisted sync
error so it can be retried.

`ConnectivityProvider` monitors network transport and internet access, while
`SyncService` uploads pending items when online and authenticated:
- field updates are sent in batches of up to 100 to `/api/v1/sync/batch`
- financial transactions are sent one-by-one to
  `/api/v1/projects/{projectId}/financial-transactions`

Failed or missing item results remain queued with a persisted error and retry
automatically after the next connection cycle or manually from the Sync Queue
screen.
