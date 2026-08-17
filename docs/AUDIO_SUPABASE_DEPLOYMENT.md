# Audio Supabase deployment

The repository now contains the backend contract, but deployment requires
your Supabase and GitHub credentials. Do not paste any secret into source,
`Info.plist`, an xcconfig, or a chat message.

## 1. Add the GitHub Actions secrets

In the repository settings under Actions secrets, add:

- `SUPABASE_ACCESS_TOKEN`: create this from the Supabase account access-token
  page. It lets the CLI link and deploy the project.
- `SUPABASE_DB_PASSWORD`: the database password for this Supabase project.
  The migration workflow needs it for `supabase db push`.

The project reference is already recorded in the workflow as
`nfzvlvukbeapcnlmyecf`. If the project reference ever changes, update the
workflow and the production/staging xcconfig endpoints together.

## 2. Deploy the bucket and functions

Run the manual GitHub Actions workflow named **Deploy audio catalog backend**.
It applies the private `audio-catalog` bucket migration and deploys:

- `audio-manifest`
- `audio-authorize`

The function URLs are:

```text
https://nfzvlvukbeapcnlmyecf.supabase.co/functions/v1/audio-manifest
https://nfzvlvukbeapcnlmyecf.supabase.co/functions/v1/audio-authorize
```

## 3. Upload the verified binary deliveries

The large audio directory is intentionally not in Git. From the repository
root on the machine that has the audio assets, get the project URL from the
Supabase project API settings and temporarily set:

```powershell
$env:SPC_SUPABASE_URL = 'https://nfzvlvukbeapcnlmyecf.supabase.co'
$env:SPC_SUPABASE_SERVICE_ROLE_KEY = '<service-role-key-from-supabase-api-settings>'
```

Run the safe hash-only pass first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\upload_audio_catalog.ps1 -DryRun
```

After the dry run reports all 14 objects as validated, run the same command
without `-DryRun` to upload them. The script uploads only verified hashes to
the private bucket and never prints the service-role key. Clear the temporary
environment values immediately afterward:

```powershell
Remove-Item Env:SPC_SUPABASE_SERVICE_ROLE_KEY
Remove-Item Env:SPC_SUPABASE_URL
```

The app only uses the manifest and signed URLs. The service-role key is never
an iOS runtime value.
