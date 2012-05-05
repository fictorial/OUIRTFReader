// Copyright 1997-2005, 2007-2011 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniBase/objc.h>
#import <stddef.h> // For size_t
#import <Foundation/NSString.h>
#import <CoreFoundation/CFNumber.h>

@class NSDictionary;

extern void OFLog(NSString *messageFormat, ...);
extern NSString *OFGetInput(NSStringEncoding encoding, NSString *promptFormat, ...);

#if 0 // Should probably use KVC
extern void OFSetIvar(NSObject *object, NSString *ivarName, NSObject *ivarValue);
extern NSObject *OFGetIvar(NSObject *object, NSString *ivarName);
#endif

// Makes NSCoding methods simpler.  Note that if 'var' is an object, you DO NOT
// have to retain it afterward a decode; -decodeValueOfObjCType:at: retains it
// for you.
#define OFEncode(coder, var) [coder encodeValueOfObjCType: @encode(typeof(var)) at: &(var)];
#define OFDecode(coder, var) [coder decodeValueOfObjCType: @encode(typeof(var)) at: &(var)];

// This returns the root class for the class tree of which aClass is a member.
static inline Class OFRootClassForClass(Class aClass)
{
    Class superClass;
    while ((superClass = class_getSuperclass(aClass)))
	aClass = superClass;
    return superClass;
}

extern BOOL OFInstanceIsKindOfClass(id instance, Class aClass);

extern NSString *OFDescriptionForObject(id object, NSDictionary *locale, unsigned indentLevel);

extern SEL OFRegisterSelectorIfAbsent(const char *selName);

#define OFStackAllocatedNameForPointer(object) \
	OFNameForPointer(object, alloca(OF_MAX_CLASS_NAME_LEN))

#define OFLockRegion_Begin(theLock) NS_DURING [theLock lock];
#define OFLockRegion_End(theLock) NS_HANDLER { [theLock unlock]; [localException raise]; } NS_ENDHANDLER [theLock unlock];

#define OFForEachObject(enumExpression, valueType, valueVar) NSEnumerator * valueVar ## _enumerator = (enumExpression); valueType valueVar; while( (valueVar = [ valueVar ## _enumerator nextObject]) != nil)

#define OFForEachInArray(arrayExpression, valueType, valueVar, loopBody) { NSArray * valueVar ## _array = (arrayExpression); NSUInteger valueVar ## _count , valueVar ## _index; valueVar ## _count = [( valueVar ## _array ) count]; for( valueVar ## _index = 0; valueVar ## _index < valueVar ## _count ; valueVar ## _index ++ ) { valueType valueVar = [( valueVar ## _array ) objectAtIndex:( valueVar ## _index )]; loopBody ; } }

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
extern uint32_t OFLocalIPv4Address(void);
#endif

// A string which uniquely identifies this computer. Currently, it's the MAC address for the built-in ethernet port, but that or the underlying implementation could change.
extern NSString *OFUniqueMachineIdentifier(void);

// A name which identifies this computer.
extern NSString *OFHostName(void);

// The local hostname - even if we have a FQDN
extern NSString *OFLocalHostName(void);

// Utilities for dealing with language names and ISO codes. If either function fails to find a translation match, it'll return its argument.
extern NSString *OFISOLanguageCodeForEnglishName(NSString *languageName);
extern NSString *OFLocalizedNameForISOLanguageCode(NSString *languageCode);

// Converts an OSError to a number, hopefully along with a less cryptic string (e.g. "File not found" or at least "fnfErr").
extern NSString *OFOSStatusDescription(OSStatus err);

// Formats a four character code into a ASCII representation.  This can take up to 4*3+1 characters.  Each byte can be up to three characters ('\ff'), plus the trailing NULL.  Returns the given fccString for ease in passing to NSLog/printf.
// The fcc is really a FourCharCode (or OSType, OSStatus, ComponentResult, etc, etc, etc).  Don't want to include MacTypes.h here though.
extern char *OFFormatFCC(uint32_t fcc, char fccString[13]);

// Parses a FourCharCode (or OSType) from an ObjC property-list type. This is compatible with the strings created by UTCreateStringForOSType(), but also accepts NSDatas and NSNumbers. Returns YES if successful, NO if not.
BOOL OFGet4CCFromPlist(id pl, uint32_t *fourcc);

// Creates a property-list representation of the given FourCharCode. Not necessarily compatible with UTGetOSTypeFromString(), because it might not return an NSString.
id OFCreatePlistFor4CC(uint32_t fourcc) NS_RETURNS_RETAINED;

// Converts between CFNumberType and numeric C types represented using @encode. Returns 0 or NULL if there's no exact equivalent (e.g. most of the unsigned integer types).
CFNumberType OFCFNumberTypeForObjCType(const char *objCType) __attribute__ ((const));
const char *OFObjCTypeForCFNumberType(CFNumberType cfType) __attribute__ ((const));

// Returns a NSUInteger containing most of the hash variation of its uintptr_t argument.
static inline NSUInteger OFHashUIntptr(uintptr_t v)
{
    // All of the conditionals in here should get constant-folded and optimized out at compile time...
    if (sizeof(NSUInteger) >= sizeof(uintptr_t)) {
        return (NSUInteger)v;
    }
#if 0
    /* Sigh. This code is perfectly valid, but the compiler isn't smart enough to know that it shouldn't warn about the overlarge shift because it's about to eliminate it as an unreachable branch. Eliminating this on non-LP64 so we can compile with -Werror. We don't really lose anything since in the actual case, NSUInteger is exactly half the size of uintptr_t, and so we get the right behavior from the last line. */
    else if (sizeof(NSUInteger) <= 2*sizeof(uintptr_t)) {
        return (NSUInteger)(v >> (8*sizeof(NSUInteger))) ^ (NSUInteger)v;
    }
#endif
    else {
        return (NSUInteger)(v >> (8*(sizeof(uintptr_t)-sizeof(NSUInteger)))) ^ (NSUInteger)v;
    }
}

typedef BOOL (^OFPredicateBlock)(id object);
typedef id (^OFObjectToObjectBlock)(id anObject);

/* NSFoundationVersionNumber values for various OS releases (since Apple only ever includes past releases in the headers, and we often want to know the current or even a "future" (from this SDK's viewpoint) version number) */
#define OFFoundationVersionNumber10_4_11 NSFoundationVersionNumber10_4_11
#define OFFoundationVersionNumber10_5    677
#define OFFoundationVersionNumber10_5_7  677.24
#define OFFoundationVersionNumber10_5_8  677.26
#define OFFoundationVersionNumber10_6    747

