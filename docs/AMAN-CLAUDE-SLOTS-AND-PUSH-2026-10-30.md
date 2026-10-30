# Superseded: use the Apple-key-only prompt

The owner clarified the division of work: Aman's Claude only obtains the APNs
key/details. Ajay's agent continues slot-performance/backend work and handles
Firebase upload/configuration. Do not assign slot optimization to Aman using
the earlier combined prompt.

Use [AMAN-CLAUDE-APNS-KEY-ONLY-2026-10-30.md](AMAN-CLAUDE-APNS-KEY-ONLY-2026-10-30.md).
Keep the private `.p8` outside Git and transfer it privately to Ajay. Only a
secret-free status note belongs in the repository.
