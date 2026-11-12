# CareMatch MVP

A small, framework-free recruitment matching prototype for the UK care sector. It uses HTML, CSS and vanilla JavaScript, Supabase Auth/Postgres, and can be hosted on GitHub Pages.

## What's included

- Candidate and employer registration/login (email + password)
- Candidate profile with care skills, town, experience and employment preference
- Employer vacancy creation and management
- Shared skills catalogue
- Transparent matching score: skills (70%), experience (20%), town match (10%)
- Employer candidate results with matched and missing required skills
- Candidate job browsing and expressions of interest
- Employer application status management and candidate shortlisting
- Row Level Security policies and a restricted matching database function

### Deliberate MVP limitations

This first cut is a functional foundation, not a production recruitment or compliance platform. Location matching is an exact town-name comparison, not a postcode-distance calculation. Shift availability, qualifications, DBS/right-to-work verification, document storage, messaging, email notifications, interview booking, payments and admin screens are not implemented yet. The current skills selected on a vacancy are treated as required skills. The matching score is decision support only; it must not make or automate hiring decisions.

## 1. Create your Supabase project

1. Go to [https://supabase.com](https://supabase.com) and sign in or create an account.
2. Select **New project**.
3. Choose an organisation, enter a project name such as `carematch-mvp`, set a strong database password and choose a region close to your users (for a UK pilot, choose a UK/EU region if available).
4. Wait for the project to finish provisioning.
5. In the Supabase project, open **SQL Editor** from the left menu.
6. Select **New query**.
7. Open the `supabase-schema.sql` file in this project, copy all its contents, paste into the SQL Editor and click **Run**.
8. Check the query completes without errors. It creates the tables, seed skills, authentication profile trigger, Row Level Security policies and matching function.

Run this against a fresh project. If you have already created tables with the same names, stop and inspect your database first rather than blindly rerunning the script.

## 2. Get the Supabase connection details

1. In Supabase, open **Project Settings** (cog icon).
2. Find **API** or **API Keys** (the dashboard wording can vary).
3. Copy the **Project URL**.
4. Copy the **anon / publishable key**. Depending on the dashboard version, this may be labelled `anon` or `publishable`.
5. Open `config.js` in VS Code.
6. Replace the placeholders:

```js
window.CAREMATCH_CONFIG = {
  supabaseUrl: 'https://YOUR-PROJECT-REF.supabase.co',
  supabaseAnonKey: 'YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY'
};
```

The browser needs the anon/publishable key. **Never put the `service_role` or secret key in `config.js`, HTML, JavaScript or GitHub.** The anon key is intended to be public; Row Level Security is what protects the data.

## 3. Configure email authentication

1. In Supabase, open **Authentication → URL Configuration**.
2. For local testing, add `http://localhost:8000` to **Redirect URLs**.
3. When you deploy, add your GitHub Pages URL, for example `https://YOUR-GITHUB-USERNAME.github.io/carematch-mvp/`.
4. Set the **Site URL** to your deployed URL once you have deployed. You can keep the local URL while developing.
5. In **Authentication → Providers → Email**, keep Email enabled.
6. For a real pilot, leave email confirmation enabled and configure SMTP/custom email delivery before inviting real users. Supabase's default email service has testing limits.

The SQL trigger creates a `pending` profile when a user signs up. The app then asks the user to choose Candidate or Employer. Users cannot promote themselves to admin or switch account types later through the normal app.

## 4. Run it on your computer

1. Download and unzip the project.
2. Open the `carematch-mvp` folder in VS Code.
3. Add your Supabase details to `config.js` and save.
4. Open a terminal in the project folder.
5. Run a local web server:

```bash
python -m http.server 8000
```

6. Visit `http://localhost:8000` in your browser.

Do not just double-click `index.html`; using a local web server avoids browser restrictions and makes auth redirects behave more like the deployed site.

## 5. Test the main user journeys

Use separate email addresses (or separate private/incognito browser sessions) for each account type.

**Candidate test**
1. Register with a test email.
2. Choose **Care professional**.
3. Complete the candidate profile and select a few skills.
4. Browse published jobs and express interest in one.
5. Open My applications and check the application appears.

**Employer test**
1. Register with a second test email.
2. Choose **Care provider**.
3. Create and publish a vacancy, selecting required skills.
4. Open Find candidates and select the vacancy.
5. Review the match score, matched skills and missing required skills.
6. Shortlist a candidate.
7. Open Applications to review candidate expressions of interest and update statuses.

To see a meaningful match, create a candidate first, give them some skills, then create an employer vacancy with overlapping skills and the same town.

## 6. Publish with GitHub Pages

1. Create a new GitHub repository called `carematch-mvp`.
2. Upload the contents of this folder to the repository root. `index.html` should be at the root, not inside another nested folder.
3. Commit and push the files.
4. In GitHub, open the repository **Settings → Pages**.
5. Under **Build and deployment**, choose **Deploy from a branch**.
6. Select branch `main` and folder `/ (root)`, then save.
7. Wait for GitHub Pages to publish. Your site will be available at `https://YOUR-GITHUB-USERNAME.github.io/carematch-mvp/`.
8. Add that exact URL to Supabase **Authentication → URL Configuration → Redirect URLs** and set it as the Site URL.

Every time you push a change to the selected branch, GitHub Pages will publish the updated static files.

## 7. Important security and UK care-sector notes

- Keep RLS enabled. Do not disable policies to make a screen work.
- Do not expose a service-role/secret key in the frontend.
- The matching function only returns limited candidate details to the employer who owns the selected published vacancy. It does not return phone numbers or email addresses.
- Candidate contact details are not displayed in the employer matching list. Add a consent-led contact-sharing workflow before using this with real applicants.
- Do not collect DBS certificates, identity documents, health information or other sensitive records in this prototype.
- Candidate-provided skills and experience are unverified. Add evidence/verification workflows before relying on them for care placements.
- Build and test against UK GDPR, the Data Protection Act 2018, Equality Act 2010, employment rules and relevant care-sector safeguarding requirements before a live commercial launch. Obtain appropriate legal and data-protection advice.
- The score is a transparent relevance aid, not a suitability guarantee. Employers must review candidates fairly and make their own decisions. Test the matching criteria for unfair or discriminatory outcomes.

## 8. Suggested next development steps

1. Add qualification requirements and candidate qualifications.
2. Add shift/day availability matching.
3. Replace town equality with proper postcode distance calculation using a trusted postcode/geocoding provider.
4. Add employer organisation profiles and verified multi-user branch accounts.
5. Add consent-based contact reveal, messaging and email notifications.
6. Add admin tools, moderation, audit logs and compliance status tracking.
7. Add automated tests and a production deployment process.

## File guide

- `index.html` – application shell and script/style loading
- `styles.css` – responsive visual design
- `app.js` – frontend behaviour and Supabase queries
- `config.js` – public Supabase URL and anon/publishable key
- `supabase-schema.sql` – database schema, seed data, RLS and matching function


## Registration account types update

The registration page now asks users to choose **Care professional** or **Care provider** before creating their account. The selection is sent as Supabase Auth user metadata and copied into `profiles.role` by the database trigger.

Because your Supabase tables already exist, run `supabase-registration-role-update.sql` once in **Supabase Dashboard → SQL Editor → New query → Run**. Do not rerun the full schema on your existing project. Upload the updated `app.js` and `styles.css` to GitHub Pages. The existing `config.js` remains unchanged.

Existing accounts created before this update with `profiles.role = 'pending'` will still be asked to choose an account type when they next log in. Existing candidate/employer roles are not changed.
