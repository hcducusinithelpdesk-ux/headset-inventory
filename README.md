# Headset Inventory Flutter Starter â€” Login Edition

## Login preview
- Username: `administrator`
- Password: `P@ssw0rd`
- Admin can add/remove view-only accounts in User Management.
- Viewer accounts can view dashboard, inventory, assignments and reports; add/edit/delete controls are hidden.

## Run
```bash
flutter pub get
flutter run -d chrome
```
Windows desktop:
```bash
flutter config --enable-windows-desktop
flutter run -d windows
```

## Important security limitation
Viewer accounts are stored in the Cloudflare D1 database with salted password hashes, so accounts created by the administrator can sign in from other networks and devices. A local copy is retained for offline use. The administrator login is still a demo credential, and the inventory API is public; add server-side authorization before using real company or employee data.

The Flutter app uses a Cloudflare Pages Function at `/api/headsets`, backed by the D1 database configured in `wrangler.jsonc`. The app polls the shared inventory every four seconds so dashboard, inventory, and assignments stay current across open sessions. It also caches the last data locally for offline viewing.

## Deploy the Flutter web app with Cloudflare Wrangler

The Wrangler configuration serves the Flutter release output from `build/web`. This project currently does not include Flutter's `web/` platform scaffold, so add it once from the project root:

```bash
flutter create . --platforms web
flutter pub get
```

Build the web app, then preview it with Wrangler:

```bash
flutter build web
npx wrangler@latest dev
```

When the preview looks right, log in to Cloudflare and deploy:

```bash
npx wrangler@latest login
npx wrangler@latest deploy
```

Initialize the D1 table once, then deploy the Pages output together with the `functions/` directory:

```bash
npx wrangler d1 execute inventory --remote --file=migrations/0001_create_headsets.sql
flutter build web
npx wrangler pages deploy build/web --project-name headset-inventory --branch main
```

The login in this starter is a client-side demo gate. The D1 API is public, so do not store confidential employee or inventory information until server-side authentication and authorization are added. The separate `portal/` site served by `server.js` is not included.

## Test the Flutter app as a website with GitHub Pages

A GitHub Actions workflow builds the Flutter web app and deploys it to GitHub Pages whenever you push to `main`. It also supports a manual run from the repository's Actions tab.

In the repository settings, open **Pages** and set the build source to **GitHub Actions**. After the workflow succeeds, open **Settings â†’ Pages** to see the website URL. The site uses demo mode unless Supabase build-time values are explicitly configured.

