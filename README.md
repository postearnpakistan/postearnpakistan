# PostEarn Pakistan — free starter website
A bilingual (English/Urdu) mobile-friendly community prototype using static HTML/CSS/JavaScript and Supabase. It includes:
- Email/password registration and login
- Automatic member profiles
- Post submission (pending until an admin approves it)
- Approved public feed (available to signed-in members)
- Likes and comments
- One counted view per signed-in user per approved post; authors' own views are not counted
- Admin moderation queue
- No cash wallet or payout promise in this starter
## Requirements
- Free GitHub account
- Free Supabase project
- Free Cloudflare Pages project
- Internet access
## 1. Create the Supabase project
1. Visit https://supabase.com/ and create a project.
2. In the Supabase dashboard, open SQL Editor -> New query.
3. Copy all contents of `supabase.sql`, paste them into the editor, and click Run.
4. Open Project Settings -> API (or the project's Connect/API details). Copy the Project URL and the anon/public publishable key. Never use a `service_role` or secret key in browser code.
5. In `app.js`, replace:
   - `YOUR_SUPABASE_PROJECT_URL`
   - `YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY`
6. In Authentication -> URL Configuration, set your local/site URL once known. During development, add the local URL you use and the deployed Cloudflare Pages URL to the allowed redirect URLs if required by your auth settings.
7. For an initial test, you may turn off email confirmation only if you understand the security trade-off; otherwise keep confirmation enabled and confirm the signup email. Production sites should use email confirmation.
## 2. Test locally
You can open `index.html` for a visual preview, but browser auth redirects and some browser security rules work better from a local web server. On a computer with Python installed, run this command inside this folder:
```bash
python -m http.server 8000
```
Then open http://localhost:8000. On a phone, you can upload the files to GitHub and use the Cloudflare Pages deployment URL to test instead.
## 3. Deploy with GitHub + Cloudflare Pages
1. Create a new GitHub repository, for example `postearn-pakistan`.
2. Upload `index.html`, `styles.css`, `app.js`, and `supabase.sql` (you can include this README too). Do not upload passwords, private keys or user data.
3. Sign in at https://pages.cloudflare.com/ and create a project connected to that GitHub repository.
4. For a plain static site, choose no build command and set the output directory to `/` (the repository root). Follow the current Cloudflare Pages prompts if its UI differs.
5. Deploy and open the generated `*.pages.dev` address.
6. In Supabase Authentication URL Configuration, add the deployed URL as the Site URL / allowed redirect URL as appropriate.
## 4. Make yourself the administrator
1. Sign up through the site using the email you control.
2. In Supabase -> Authentication -> Users, copy your user UUID.
3. In SQL Editor, run this query after replacing the placeholder with your UUID:
```sql
update public.profiles
set role = 'admin'
where id = 'YOUR_AUTH_USER_UUID';
```
4. Log out and log back in. The Admin moderation queue should appear. Never create an admin option on the public signup form.
## 5. Test the core flow
1. Sign up with your own email and confirm it if confirmation is enabled.
2. Submit a post; it should remain pending and not appear in the public feed.
3. Use the admin account to approve the post.
4. Sign in as a second test user, open the post, like it and comment.
5. Check the view counter. It counts at most one view per signed-in user per post and does not count the author's own views. It is a basic anti-abuse measure, not a complete fraud-detection system.
## Important limitations and safety
- This is a starter prototype, not a fully audited production platform.
- Public display-name and post content are untrusted input; the app escapes text before inserting it into the page.
- Views count only authenticated users. Automated traffic, account farms and coordinated engagement can still be abused. Do not base cash rewards solely on these counters.
- Do not pay for ad clicks or incentivize ad interactions. Advertising policies can prohibit this.
- There is no wallet, cash balance, payout request, bank detail collection or automated payment in this version.
- Before any cash rewards, publish eligibility rules and terms, secure funding first, establish a review/appeal process, and consult qualified advice on applicable Pakistani tax, privacy, consumer and payment requirements.
- Free hosting/database plans have limits and may pause or change. Back up data and check current plan details before inviting many users.
- For production, add rate limiting, spam reporting, account deletion, email verification, content reporting, stronger moderation, monitoring, backups and a security review.
