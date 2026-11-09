# Privacy and transfer model

No Supabase, cloud login, OAuth, or API sync. Records live only in local IndexedDB. Financial data is neither in the public web build nor in GitHub. PWA visitors use their own browser-origin storage; on shared computers the same browser profile can open the same local records. Use trusted, screen-locked devices.

To move entries between devices: export JSON from the source device; import JSON on target; confirm full replacement of local entries. There is no automatic merging, no real-time sync, and no automatic backup. Excel export is for reading and printing, not for restoring transactions. Delete or protect exported files appropriately. Never commit them into source control. Clearing site data, changing URL/host, OS eviction, or uninstalling may erase data. Make frequent encrypted-device/cloud-drive backups of your exported JSON if desired, using your own storage provider.
