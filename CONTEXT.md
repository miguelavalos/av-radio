# AV Radio Context

## Domain Terms

- **AV Radio**: the local-first radio listening product. The public repo owns native clients, local playback, local persistence, and public app configuration.
- **AV Apps**: the private platform that owns account, entitlement, subscription, admin, marketing, and backend infrastructure shared by Avalsys apps.
- **AV Apps Account**: the provider-agnostic account identity exposed to product surfaces. Product code should not expose identity-provider names unless it is inside a provider Adapter.
- **local mode**: the product-facing mode for a user without an AV Apps Account connection. Data stays on the device.
- **connected account**: the product-facing mode for a signed-in free user. Identity is connected, but AV Radio library data remains local-only unless capabilities say otherwise.
- **pro**: the paid access mode. Pro may unlock backend-owned features and cloud sync according to entitlement capabilities.
- **entitlement**: the backend-owned resolution of plan tier, access mode, capabilities, and limits for one app and one user.
- **capability**: a specific permission derived from entitlement, such as cloud sync, backend use, premium features, or plan management.
- **library**: the user's AV Radio collection state, including favorites, recents, discoveries, saved tracks, and settings.
- **app data**: backend-stored per-user, per-app documents used for cloud sync.
- **library sync**: the workflow that compares local library state with app data, merges or rejects conflicting changes, and commits a new revision.

## Architectural Terms

- **Module**: anything with an interface and an implementation.
- **Interface**: everything a caller must know to use a Module correctly.
- **Adapter**: a concrete thing satisfying an interface at a seam.
- **Seam**: where behaviour can vary without editing the caller.
- **Locality**: change and verification concentrated in one Module.
- **Leverage**: more behaviour behind a smaller interface.

## Current Seams

- `public/av-radio/shared/apple` is the shared Apple Module for iOS and macOS behaviour.
- `public/av-radio/shared/contracts` holds public platform-neutral AV Radio contracts used to validate native client policy.
- `private/av-apps/packages/contracts` is the TypeScript contract Module for the private backend and frontend.
- `private/av-apps/services/api/src/services/platform` owns backend Modules for account, entitlement, subscription, app data, and admin workflows.
- `private/av-apps/apps/account/src/lib` owns frontend Adapters for the Account app's backend calls.
