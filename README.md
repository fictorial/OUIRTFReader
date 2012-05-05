# OmniGroup's RTF Reader 

1. Add the RTFReader folder to your XCode project.

2. Add the following to your project's prefix.pch.

    #import <OmniBase/OmniBase.h>
    #import <OmniFoundation/OFCharacterSet.h>
    #import <OmniFoundation/OFStringScanner.h>
    #import <OmniFoundation/OFNull.h>

3. Link with CoreText.framework.

4. Use the RTF reader.

    NSString *rtfString = ...
    NSString *plainTextString = [[OUIRTFReader parseRTFString:rtfString] string];

## Why did I do this?

1. I needed a way to convert RTF encoded strings to plain text.
2. I did not wish to force users of my project to include all of OmniGroup's
   frameworks.
3. I enjoy pain?

---

There is probably more included here than strictly needed.

I am of course open to pull requests that simplify any or all of this.
