// Copyright 1997-2012 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <AvailabilityMacros.h>
#import <Foundation/NSAutoreleasePool.h>

#if !defined(SWAP)
#define SWAP(A, B) do { __typeof__(A) __temp = (A); (A) = (B); (B) = __temp;} while(0)
#endif

// These macros are expanded out because if you do something like MIN(MIN(A,B),C), you'll get a shadowed local variable warning. It's harmless in that case but the warning does occasionally point out bad code elsewhere, so I want to avoid causing it spuriously.

#define MIN3(A, B, C) ({ __typeof__(A) __temp1 = (A); __typeof__(B) __temp2 = (B); if (__temp2 < __temp1) { __temp1 = __temp2; } __temp2 = (C); (__temp2 < __temp1)? __temp2 : __temp1; }) 
#define MAX3(A, B, C) ({ __typeof__(A) __temp1 = (A); __typeof__(B) __temp2 = (B); if (__temp2 > __temp1) { __temp1 = __temp2; } __temp2 = (C); (__temp2 > __temp1)? __temp2 : __temp1; }) 

#define MIN4(A, B, C, D) ({ __typeof__(A) __temp1 = (A); __typeof__(B) __temp2 = (B); if (__temp2 < __temp1) { __temp1 = __temp2; } __typeof__(C) __temp3 = (C); __typeof__(D) __temp4 = (D);  if (__temp4 < __temp3) { __temp3 = __temp4; } (__temp1 < __temp3)? __temp1 : __temp3; })
#define MAX4(A, B, C, D) ({ __typeof__(A) __temp1 = (A); __typeof__(B) __temp2 = (B); if (__temp2 > __temp1) { __temp1 = __temp2; } __typeof__(C) __temp3 = (C); __typeof__(D) __temp4 = (D);  if (__temp4 > __temp3) { __temp3 = __temp4; } (__temp1 > __temp3)? __temp1 : __temp3; })

/* The CLAMP() macro constrains a value to a range, like MIN(MAX()). Min and max are implicitly coerced to the same type as value. */
#define CLAMP(value, min, max) ({ __typeof__(value) __temp_value = (value); __typeof__(value) __temp_min = (min); ( __temp_value < __temp_min )? __temp_min : ({ __typeof__(value) __temp_max = (max); ( __temp_value > __temp_max )? __temp_max : __temp_value; }); })

// On Solaris, when _TS_ERRNO is defined <errno.h> defines errno as the thread-safe ___errno() function.
// On NT, errno is defined to be '(*_errno())' and presumably this function is also thread safe.
// On MacOS X, errno is defined to be '(*__error())', which is also presumably thread safe. 

#import <errno.h>
#define OMNI_ERRNO() errno

#define OMNI_POOL_START				\
do {						\
    NSAutoreleasePool *__pool;			\
    __pool = [[NSAutoreleasePool alloc] init];	\
    @try {

#define OMNI_POOL_END \
    } @catch (NSException *__exc) { \
	[__exc retain]; \
	[__pool release]; \
	__pool = nil; \
	[__exc autorelease]; \
	[__exc raise]; \
    } @finally { \
	[__pool release]; \
    } \
} while(0)

// For when you have an outError to deal with too
#define OMNI_POOL_ERROR_END \
    } @catch (NSException *__exc) { \
        if (outError) \
            *outError = nil; \
        [__exc retain]; \
        [__pool release]; \
        __pool = nil; \
        [__exc autorelease]; \
        [__exc raise]; \
    } @finally { \
        if (outError) \
            [*outError retain]; \
        [__pool release]; \
        if (outError) \
            [*outError autorelease]; \
    } \
} while(0)

// We don't want to use the main-bundle related macros when building other bundle types.  This is sometimes what you want to do, but you shouldn't use the macros since it'll make genstrings emit those strings into your bundle as well.  We can't do this from the .xcconfig files since NSBundle's #define wins vs. command line flags.
#import <Foundation/NSBundle.h> // Make sure this is imported first so that it doesn't get imported afterwards, clobbering our attempted clobbering.
#if defined(OMNI_BUILDING_BUNDLE) || defined(OMNI_BUILDING_FRAMEWORK)
    #undef NSLocalizedString
    #define NSLocalizedString Use_NSBundle_methods_if_you_really_want_to_look_up_strings_in_the_main_bundle
    #undef NSLocalizedStringFromTable
    #define NSLocalizedStringFromTable Use_NSBundle_methods_if_you_really_want_to_look_up_strings_in_the_main_bundle
#endif

// Hack to define a protocol for OBPerformRuntimeChecks() to check for deprecated dataSource/delegate methods where _implementing_ a method with a given name is considered wrong (likely the method has been removed from the protocol or renamed). The inline is enough to trick the compiler into emitting the protocol into the .o file, though this seems fragile.  OBPostLoader will use this macro itself once and will assert that at least one such deprecated protocol is found, just to make sure this hack keeps working. This macro is intended to be used in a .m file; otherwise the hack function defined would get multiple definitions.
// Since these protocols are only examied when assertions are enabled, this should be wrapped in a OMNI_ASSERTIONS_ON check.
#import <OmniBase/assertions.h> // Since we want you to use OMNI_ASSERTIONS_ON, make sure it is imported
#ifdef OMNI_ASSERTIONS_ON
    extern void OBRuntimeCheckRegisterDeprecatedMethodWithName(const char *name);

    #define OBDEPRECATED_METHOD__(name, line) \
    static void OBRuntimeCheckRegisterDeprecated_ ## line(void) __attribute__((constructor)); \
    static void OBRuntimeCheckRegisterDeprecated_ ## line(void) { \
        OBRuntimeCheckRegisterDeprecatedMethodWithName(#name); \
    }

    #define OBDEPRECATED_METHOD_(name, line) OBDEPRECATED_METHOD__(name, line)
    #define OBDEPRECATED_METHOD(name) OBDEPRECATED_METHOD_(name, __LINE__)
#else
    #define OBDEPRECATED_METHOD(name)
#endif

/*
 OB_BUILTIN_ATOMICS_AVAILABLE: Some compilers have builtins which compile to efficient atomic memory operations.
 On x86, it knows to use the LOCK prefix; on ARM, we get the ldrex/strex/dmb instructions, etc. The names seem to be derived from an Intel intrinsics library, but GCC picked them up and then Clang did.
 If the builtins are not available, code can fall back to the routines in <libkern/OSAtomic.h>.
*/

/* Newer clangs have the builtin atomics that GCC does, and the handy __has_builtin macro */
#if defined(__has_builtin)
#if __has_builtin(__sync_synchronize) && __has_builtin(__sync_bool_compare_and_swap)
#define OB_BUILTIN_ATOMICS_AVAILABLE
#endif
#endif
/* GCC 4.1.x has some builtins for atomic operations */
#if !defined(OB_BUILTIN_ATOMICS_AVAILABLE) && defined(__GNUC__)
#if ((__GNUC__ * 100 + __GNUC_MINOR__ ) >= 401)  // gcc version >= 4.1.0
#ifndef __clang__ // Radar 6964106: clang doesn't have __sync_synchronize builtin (but it claims to be GCC)
#define OB_BUILTIN_ATOMICS_AVAILABLE
#endif
#endif
#endif

/* For doing retain-and-assign or copy-and-assign with CF objects */
#define OB_ASSIGN_CFRELEASE(lval, rval) { __typeof__(lval) new_ ## lval = (rval); if (lval != NULL) { CFRelease(lval); } lval = new_ ## lval; }


// ARC/MRR support

#if defined(__has_feature) && __has_feature(objc_arc)
    #define OB_STRONG __strong
    #define OB_BRIDGE __bridge
    #define OB_AUTORELEASING __autoreleasing
#else
    #define OB_STRONG
    #define OB_BRIDGE
    #define OB_AUTORELEASING
#endif
