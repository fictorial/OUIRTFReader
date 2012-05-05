// Copyright 1997-2008, 2010-2012 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSDictionary-OFExtensions.h>

#import <OmniFoundation/NSString-OFSimpleMatching.h>
#import <OmniFoundation/NSMutableArray-OFExtensions.h>
#import <OmniBase/rcsid.h>
#import <OmniBase/assertions.h>
#include <stdlib.h>

RCS_ID("$Id$")

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    #define CGPointValue pointValue
    #define CGRectValue rectValue
    #define CGSizeValue sizeValue
#else
    #import <UIKit/UIGeometry.h>
    #define NSPointFromString CGPointFromString
    #define NSRectFromString CGRectFromString
    #define NSSizeFromString CGSizeFromString
    #define NSZeroPoint CGPointZero
    #define NSZeroSize CGSizeZero
    #define NSZeroRect CGRectZero
#endif

#define SAFE_ALLOCA_SIZE (8 * 8192)

@implementation NSDictionary (OFExtensions)

- (id)anyObject;
{
    for (NSString *key in self)
        return [self objectForKey:key];
    return nil;
}

/*" Returns an object which is a shallow copy of the receiver except that the given key now maps to anObj. anObj may be nil in order to remove the given key from the dictionary. "*/
- (NSDictionary *)dictionaryWithObject:(id)anObj forKey:(NSString *)key;
{
    NSUInteger keyCount = [self count];
    
    if (keyCount == 0 || (keyCount == 1 && [self objectForKey:key] != nil))
        return anObj ? [NSDictionary dictionaryWithObject:anObj forKey:key] : [NSDictionary dictionary];

    if ([self objectForKey:key] == anObj)
        return [NSDictionary dictionaryWithDictionary:self];

    NSMutableArray *newKeys = [[NSMutableArray alloc] initWithCapacity:keyCount+1];
    NSMutableArray *newValues = [[NSMutableArray alloc] initWithCapacity:keyCount+1];
    
    for (NSString *aKey in self) {
        if (![aKey isEqual:key]) {
            [newKeys addObject:aKey];
            [newValues addObject:[self objectForKey:aKey]];
        }
    }

    if (anObj != nil) {
        [newKeys addObject:key];
        [newValues addObject:anObj];
    }

    NSDictionary *result = [NSDictionary dictionaryWithObjects:newValues forKeys:newKeys];
    [newKeys release];
    [newValues release];
    
    return result;
}

/*" Returns an object which is a shallow copy of the receiver except that the key-value pairs from aDictionary are included (overriding existing key-value associations if they existed). "*/

struct dictByAddingContext {
    id *keys;
    id *values;
    NSUInteger kvPairsUsed;
    BOOL differs;
    CFDictionaryRef older, newer;
};

static void copyWithOverride(const void *aKey, const void *aValue, void *_context)
{
    struct dictByAddingContext *context = _context;
    NSUInteger used = context->kvPairsUsed;
    
    const void *otherValue = CFDictionaryGetValue(context->newer, aKey);
    if (otherValue && otherValue != aValue) {
        context->values[used] = (id)otherValue;
        context->differs = YES;
    } else {
        context->values[used] = (id)aValue;
    }
    context->keys[used] = (id)aKey;
    context->kvPairsUsed = used+1;
}

static void copyNewItems(const void *aKey, const void *aValue, void *_context)
{
    struct dictByAddingContext *context = _context;
    
    if(CFDictionaryContainsKey(context->older, aKey)) {
        // Value will already have been chaecked by copyWithOverride().
    } else {
        NSUInteger used = context->kvPairsUsed;
        context->keys[used] = (id)aKey;
        context->values[used] = (id)aValue;
        context->differs = YES;
        context->kvPairsUsed = used+1;
    }
}

- (NSDictionary *)dictionaryByAddingObjectsFromDictionary:(NSDictionary *)otherDictionary;
{
    struct dictByAddingContext context;

    if (!otherDictionary)
        goto nochange_noalloc;
    
    NSUInteger myKeyCount = [self count];
    NSUInteger otherKeyCount = [otherDictionary count];
    
    if (!otherKeyCount)
        goto nochange_noalloc;
    
    context.keys = calloc(myKeyCount+otherKeyCount, sizeof(*(context.keys)));
    context.values = calloc(myKeyCount+otherKeyCount, sizeof(*(context.values)));
    context.kvPairsUsed = 0;
    context.differs = NO;
    context.older = (CFDictionaryRef)self;
    context.newer = (CFDictionaryRef)otherDictionary;
    
    CFDictionaryApplyFunction((CFDictionaryRef)self, copyWithOverride, &context);
    CFDictionaryApplyFunction((CFDictionaryRef)otherDictionary, copyNewItems, &context);
    if (!context.differs)
        goto nochange;
    
    NSDictionary *newDictionary = [NSDictionary dictionaryWithObjects:context.values forKeys:context.keys count:context.kvPairsUsed];
    free(context.keys);
    free(context.values);
    return newDictionary;
    
nochange:
    free(context.keys);
    free(context.values);
nochange_noalloc:
    return [NSDictionary dictionaryWithDictionary:self];
}

- (NSString *)keyForObjectEqualTo:(id)anObject;
{
    for (NSString *key in self)
        if ([[self objectForKey:key] isEqual:anObject])
	    return key;
    return nil;
}

- (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)defaultValue;
{
    id object = [self objectForKey:key];
    if (![object isKindOfClass:[NSString class]])
        return defaultValue;
    return object;
}

- (NSString *)stringForKey:(NSString *)key;
{
    return [self stringForKey:key defaultValue:nil];
}

- (NSArray *)stringArrayForKey:(NSString *)key defaultValue:(NSArray *)defaultValue;
{
#ifdef OMNI_ASSERTIONS_ON
    for (id value in defaultValue)
        OBPRECONDITION([value isKindOfClass:[NSString class]]);
#endif
    NSArray *array = [self objectForKey:key];
    if (![array isKindOfClass:[NSArray class]])
        return defaultValue;
    for (id value in array) {
        if (![value isKindOfClass:[NSString class]])
            return defaultValue;
    }
    return array;
}

- (NSArray *)stringArrayForKey:(NSString *)key;
{
    return [self stringArrayForKey:key defaultValue:nil];
}

- (float)floatForKey:(NSString *)key defaultValue:(float)defaultValue;
{
    id value = [self objectForKey:key];
    if (value)
        return [value floatValue];
    return defaultValue;
}

- (float)floatForKey:(NSString *)key;
{
    return [self floatForKey:key defaultValue:0.0f];
}

- (double)doubleForKey:(NSString *)key defaultValue:(double)defaultValue;
{
    id value = [self objectForKey:key];
    if (value)
        return [value doubleValue];
    return defaultValue;
}

- (double)doubleForKey:(NSString *)key;
{
    return [self doubleForKey:key defaultValue:0.0];
}

- (CGPoint)pointForKey:(NSString *)key defaultValue:(CGPoint)defaultValue;
{
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]] && ![NSString isEmptyString:value])
        return NSPointFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGPointValue];
    else
        return defaultValue;
}

- (CGPoint)pointForKey:(NSString *)key;
{
    return [self pointForKey:key defaultValue:NSZeroPoint];
}

- (CGSize)sizeForKey:(NSString *)key defaultValue:(CGSize)defaultValue;
{
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]] && ![NSString isEmptyString:value])
        return NSSizeFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGSizeValue];
    else
        return defaultValue;
}

- (CGSize)sizeForKey:(NSString *)key;
{
    return [self sizeForKey:key defaultValue:NSZeroSize];
}

- (CGRect)rectForKey:(NSString *)key defaultValue:(CGRect)defaultValue;
{
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]] && ![NSString isEmptyString:value])
        return NSRectFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGRectValue];
    else
        return defaultValue;
}

- (CGRect)rectForKey:(NSString *)key;
{
    return [self rectForKey:key defaultValue:NSZeroRect];
}

- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)defaultValue;
{
    id value = [self objectForKey:key];

    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]])
        return [value boolValue];

    return defaultValue;
}

- (BOOL)boolForKey:(NSString *)key;
{
    return [self boolForKey:key defaultValue:NO];
}

- (int)intForKey:(NSString *)key defaultValue:(int)defaultValue;
{
    id value = [self objectForKey:key];
    if (!value)
        return defaultValue;
    return [value intValue];
}

- (int)intForKey:(NSString *)key;
{
    return [self intForKey:key defaultValue:0];
}

- (unsigned int)unsignedIntForKey:(NSString *)key defaultValue:(unsigned int)defaultValue;
{
    id value = [self objectForKey:key];
    if (value == nil)
        return defaultValue;
    return [value unsignedIntValue];
}

- (unsigned int)unsignedIntForKey:(NSString *)key;
{
    return [self unsignedIntForKey:key defaultValue:0];
}

- (unsigned long long int)unsignedLongLongForKey:(NSString *)key defaultValue:(unsigned long long int)defaultValue;
{
    id value = [self objectForKey:key];
    if (value == nil)
        return defaultValue;
    return [value unsignedLongLongValue];
}

- (unsigned long long int)unsignedLongLongForKey:(NSString *)key;
{
    return [self unsignedLongLongForKey:key defaultValue:0ULL];
}

- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)defaultValue;
{
    id value = [self objectForKey:key];
    if (!value)
        return defaultValue;
    return [value integerValue];
}

- (NSInteger)integerForKey:(NSString *)key;
{
    return [self integerForKey:key defaultValue:0];
}

struct _makeValuesPerformSelectorContext {
    SEL sel;
    id object;
};

static void _makeValuesPerformSelectorApplier(const void *key, const void *value, void *context)
{
    struct _makeValuesPerformSelectorContext *ctx = context;
    [(id)value performSelector:ctx->sel withObject:ctx->object];
}

- (void)makeValuesPerformSelector:(SEL)sel withObject:(id)object;
{
    struct _makeValuesPerformSelectorContext ctx = {sel, object};
    CFDictionaryApplyFunction((CFDictionaryRef)self, _makeValuesPerformSelectorApplier, &ctx);
}

- (void)makeValuesPerformSelector:(SEL)sel;
{
    [self makeValuesPerformSelector:sel withObject:nil];
}

- (id)objectForKey:(NSString *)key defaultObject:(id)defaultObject;
{
    id value = [self objectForKey:key];
    if (value)
        return value;
    return defaultObject;
}

- (id)deepMutableCopy;
{
    NSMutableDictionary *newDictionary = [self mutableCopy];
    // Run through the new dictionary and replace any objects that respond to -deepMutableCopy or -mutableCopy with copies.
    for (id aKey in self) {
	id anObject = [newDictionary objectForKey:aKey];
        if ([anObject respondsToSelector:@selector(deepMutableCopy)]) {
            anObject = [(NSDictionary *)anObject deepMutableCopy];
            [newDictionary setObject:anObject forKey:aKey];
            [anObject release];
        } else if ([anObject conformsToProtocol:@protocol(NSMutableCopying)]) {
            anObject = [anObject mutableCopy];
            [newDictionary setObject:anObject forKey:aKey];
            [anObject release];
        } else
            [newDictionary setObject:anObject forKey:aKey];
    }

    return newDictionary;
}

static id copyDictionaryKeys(CFDictionaryRef self, Class resultClass)
{
    NSUInteger keyCount = CFDictionaryGetCount(self);
    
    const void **keys;
    size_t byteCount = sizeof(*keys) * keyCount;
    BOOL useMalloc = byteCount >= SAFE_ALLOCA_SIZE;
    keys = useMalloc ? malloc(byteCount) : alloca(byteCount);
    
    CFDictionaryGetKeysAndValues((CFDictionaryRef)self, keys, NULL);
    
    id keyArray;
    keyArray = [[resultClass alloc] initWithObjects:(id *)keys count:keyCount];
    
    if (useMalloc)
        free(keys);
    
    return keyArray;
}

- (NSArray *) copyKeys;
/*.doc. Just like -allKeys on NSDictionary, except that it doesn't autorelease the result but returns a retained array. */
{
    return copyDictionaryKeys((CFDictionaryRef)self, [NSArray class]);
}

- (NSMutableArray *) mutableCopyKeys;
/*.doc. Just like -allKeys on NSDictionary, except that it doesn't autorelease the result but returns a newly created mutable array. */
{
    return copyDictionaryKeys((CFDictionaryRef)self, [NSMutableArray class]);
}

- (NSSet *) copyKeySet;
{
    return copyDictionaryKeys((CFDictionaryRef)self, [NSSet class]);
}

- (NSMutableSet *) mutableCopyKeySet;
{
    return copyDictionaryKeys((CFDictionaryRef)self, [NSMutableSet class]);
}

@end


@implementation NSDictionary (OFDeprecatedExtensions)

- (id)valueForKey:(NSString *)key defaultValue:(id)defaultValue;
{
    return [self objectForKey:key defaultObject:defaultValue];
}

@end
