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
This login edition stores viewer accounts locally in the browser/app installation using SharedPreferences. It is a functional UI/demo access gate, **not secure cloud authentication**. Viewer accounts do not automatically sync to other PCs. Do not use this local login for real company data or expose the app publicly.

The Supabase inventory connection from the previous starter is retained, but this login gate does not authenticate users to Supabase. For production cloud deployment, implement Supabase Auth and role-based Row Level Security, and provision the first administrator securely. Never store plain-text passwords in a database or ship a service-role key in a Flutter app.

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

If you use Supabase, pass the project URL and **anon** key at build time:

```bash
flutter build web --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

The anon key is exposed in the browser build, so protect the database with correct Supabase Row Level Security policies. Do not use a service-role key here. This Wrangler setup deploys the Flutter app; the separate `portal/` site served by `server.js` is not included.

## Test the Flutter app as a website with GitHub Pages

A GitHub Actions workflow builds the Flutter web app and deploys it to GitHub Pages whenever you push to `main`. It also supports a manual run from the repository's Actions tab.

In the repository settings, open **Pages** and set the build source to **GitHub Actions**. After the workflow succeeds, open **Settings â†’ Pages** to see the website URL. The site uses demo mode unless Supabase build-time values are explicitly configured.

