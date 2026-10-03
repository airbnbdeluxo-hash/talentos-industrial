# Security Policy

## Reporting a vulnerability

Do not disclose vulnerabilities in a public issue.

Report suspected vulnerabilities privately to the repository owner through a
private GitHub channel or another private contact method already established
with the project owner. Include the affected area, reproduction steps and the
minimum information necessary to verify the issue.

Please do not access, alter, download or retain data belonging to other users
while testing a suspected vulnerability.

## Security model

- Browser code must never contain service-role keys, private keys or privileged
  credentials.
- Privileged company operations are performed server-side.
- Supabase Row Level Security (RLS) is required for exposed data.
- Candidate documents are stored in private buckets.
- Security-sensitive changes must pass the repository security workflow before
  being merged.
