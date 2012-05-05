// Copyright 2003-2012 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/OAFontDescriptor.h>

#import <OmniFoundation/OFCFCallbacks.h>
#import <OmniFoundation/NSNumber-OFExtensions-CGTypes.h>
#import <OmniFoundation/NSString-OFSimpleMatching.h>
#import <OmniBase/OmniBase.h>

#import <Foundation/Foundation.h>

RCS_ID("$Id$");

//#define FONT_DESC_STATS
static NSMutableSet *_OAFontDescriptorUniqueTable = nil;
static NSLock *_OAFontDescriptorUniqueTableLock = nil;
static NSMutableArray *_OAFontDescriptorRecentInstances = nil;

@interface OAFontDescriptor (/*Private*/)
- (void)_invalidateCachedFont;
@end

@implementation OAFontDescriptor

+ (void)initialize;
{
    OBINITIALIZE;

    // We want -hash/-isEqual:, but no -retain/-release
    CFSetCallBacks callbacks = OFNSObjectSetCallbacks;
    callbacks.retain  = NULL;
    callbacks.release = NULL;
    _OAFontDescriptorUniqueTable = (NSMutableSet *)CFSetCreateMutable(kCFAllocatorDefault, 0, &callbacks);
    _OAFontDescriptorUniqueTableLock = [[NSLock alloc] init];
    
    // Keep recently created/in-use instances alive until the next call to +forgetUnusedInstances. We could have a timer running to do this periodically, but we also want to do it in response to memory warnings in UIKit and we don't really want a timer waking up every N seconds when there is nothing to do. Hopefully we'll get a memory warning point to hook into on the Mac or we can add a timer there if we need it (or we could call it when a document is closed).
    _OAFontDescriptorRecentInstances = [[NSMutableArray alloc] init];
}

+ (void)forgetUnusedInstances;
{
    NSArray *oldInstances = nil;
    
    [_OAFontDescriptorUniqueTableLock lock];
    oldInstances = _OAFontDescriptorRecentInstances;
    _OAFontDescriptorRecentInstances = nil;
    [_OAFontDescriptorUniqueTableLock unlock];
    
    [oldInstances release]; // -dealloc will clean out the otherwise unused instances
    
    [_OAFontDescriptorUniqueTableLock lock];
    if (_OAFontDescriptorRecentInstances == nil) // another thread called this?
        _OAFontDescriptorRecentInstances = [[NSMutableArray alloc] initWithArray:[_OAFontDescriptorUniqueTable allObjects]];
    [_OAFontDescriptorUniqueTableLock unlock];
}

// This is currently called by the NSNotificationCenter hacks in OmniOutliner.  Horrifying; maybe those hacks should move here, but better yet would be if we didn't need them.
+ (void)fontSetWillChangeNotification:(NSNotification *)note;
{
    // Invalidate the cached fonts in all our font descriptors.  The various live text storages are about to get a -fixFontAttributeInRange: due to this notification (this gets called specially first so that all the font descriptors are primed to recache the right fonts).
    [_OAFontDescriptorUniqueTableLock lock];
    NSArray *allFontDescriptors = [_OAFontDescriptorUniqueTable allObjects];
    [_OAFontDescriptorUniqueTableLock unlock];
    [allFontDescriptors makeObjectsPerformSelector:@selector(_invalidateCachedFont)];
}

CGFloat OAFontDescriptorDefaultFontWeight(void)
{
    return 5.0f; // NSFontManager-style weight.
}

OFExtent OAFontDescriptorValidFontWeightExtent(void)
{
    return OFExtentMake(1.0f, 13.0f); // range is inclusive, so this includes 14
}

// CoreText's font traits are often normalize -1..1 where AppKits are BOOL or an int with defined values. We don't expect the iPad/iPhone to have a zillion fonts so we'll pick the extreme values (so, we assume a weight of 1.0 will get "bold" not "super page destroying uber black").
static CGFloat _fontManagerWeightToWeight(NSInteger weight)
{
    if (weight > 8)
        return 1.0f; // 
    else if (weight < 4)
        return -1.0f;
    return 0.0f;
}

static NSInteger _weightToFontManagerWeight(CGFloat weight)
{
    if (weight < 0)
        return 2; // light-ish
    if (weight > 0.3)
        return 9; // bold-ish
    return 5; // normal
}

- initWithFontAttributes:(NSDictionary *)fontAttributes;
{
    OBPRECONDITION(fontAttributes);
    
    if (!(self = [super init]))
        return nil;
    
    _attributes = [fontAttributes copy];
    
    [_OAFontDescriptorUniqueTableLock lock];
    OAFontDescriptor *uniquedInstance = [[_OAFontDescriptorUniqueTable member:self] retain];
    if (uniquedInstance == nil) {
        [_OAFontDescriptorUniqueTable addObject:self];
        [_OAFontDescriptorRecentInstances addObject:self];
#if defined(FONT_DESC_STATS)
        NSLog(@"%lu font descriptors ++ added %@", [_OAFontDescriptorUniqueTable count], self);
#endif
    }
    [_OAFontDescriptorUniqueTableLock unlock];

    if (uniquedInstance) {
        [self release];
        return uniquedInstance;
    } else {
        _isUniquedInstance = YES; // Track that we need to remove ourselves from the table in -dealloc
        return self;
    }
}

- initWithFamily:(NSString *)family size:(CGFloat)size;
{
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    if (family)
        [attributes setObject:family forKey:(id)kCTFontFamilyNameAttribute];
    if (size > 0)
        [attributes setObject:[NSNumber numberWithCGFloat:size] forKey:(id)kCTFontSizeAttribute];

    self = [self initWithFontAttributes:attributes];
    OBASSERT([self font]); // Make sure we can cache a font
    
    [attributes release];
    return self;
}

// <bug://bugs/60459> ((Re) add support for expanded/condensed/width in OSFontDescriptor): add 'expanded' or remove 'condensed' and replace with 'width'. This would be a backwards compatibility issue w.r.t. archiving, though.
// This (currently) takes the NSFontManager-style weight. Longer term, we should just switch to archiving a plist with the entire font descriptor, maybe.  Or maybe we should just switch to archiving the 0..1 weight and width attributes.
- initWithFamily:(NSString *)family size:(CGFloat)size weight:(NSInteger)weight italic:(BOOL)italic condensed:(BOOL)condensed fixedPitch:(BOOL)fixedPitch;
{
    OBPRECONDITION(![NSString isEmptyString:family]);
    OBPRECONDITION(size > 0.0f);
#ifdef OMNI_ASSERTIONS_ON
    NSNumber *weightNumber = [[NSNumber alloc] initWithInteger:weight]; // avoiding autoreleaes in assertion
#endif
    OBPRECONDITION(OFExtentContainsValue(OAFontDescriptorValidFontWeightExtent(), weight));
#ifdef OMNI_ASSERTIONS_ON
    [weightNumber release];
#endif
    
    if (!weight)
        weight = OAFontDescriptorDefaultFontWeight();

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    {
        if (family)
            [attributes setObject:family forKey:(id)kCTFontFamilyNameAttribute];
        if (size > 0)
            [attributes setObject:[NSNumber numberWithCGFloat:size] forKey:(id)kCTFontSizeAttribute];
        
        NSMutableDictionary *traits = [[NSMutableDictionary alloc] init];
        CTFontSymbolicTraits symbolicTraits = 0;
            
        CGFloat normalizedWeight = _fontManagerWeightToWeight(weight);
        if (normalizedWeight > 0)
            symbolicTraits |= kCTFontBoldTrait;
      
        // <bug://bugs/60460> (Deal with multiple levels of bold in OSFontDescriptor)
        // Adding this causes font lookup to fail. Need to figure out how to deal with extra-bold fonts.  Presumably the issue is that no fonts have "1.0" weight even if they are really bold.
#if 0
        if (normalizedWeight != 0)
            [traits setObject:[NSNumber numberWithCGFloat:normalizedWeight] forKey:(id)kCTFontWeightTrait];
#endif
        
        if (fixedPitch)
            symbolicTraits |= kCTFontMonoSpaceTrait;
        
        if (italic)
            symbolicTraits |= kCTFontItalicTrait;
        
        if (condensed) // We don't archive any notion of expanded.
            symbolicTraits |= kCTFontCondensedTrait;
        
        if (symbolicTraits != 0)
            [traits setObject:[NSNumber numberWithUnsignedInt:symbolicTraits] forKey:(id)kCTFontSymbolicTrait];

        if ([traits count] > 0)
            [attributes setObject:traits forKey:(id)kCTFontTraitsAttribute];
        [traits release];
    }
    
    self = [self initWithFontAttributes:attributes];
    OBASSERT([self font]); // Make sure we can cache a font
    
    [attributes release];
    return self;
}

- initWithFont:(OAFontDescriptorPlatformFont)font;
{
    OBPRECONDITION(font);

    // Note that this leaves _font as nil so that we get the same results as forward mapping via our caching.
    NSDictionary *attributes;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    CTFontDescriptorRef fontDescriptor = CTFontCopyFontDescriptor(font);
    attributes = (NSDictionary *)CTFontDescriptorCopyAttributes(fontDescriptor);
    CFRelease(fontDescriptor);
#else
    attributes = [[font fontDescriptor] fontAttributes];
#endif
    
    self = [self initWithFontAttributes:attributes];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    [attributes release];
#endif
    return self;
}

- (void)dealloc;
{
    if (_isUniquedInstance) {
        [_OAFontDescriptorUniqueTableLock lock];
        OBASSERT([_OAFontDescriptorUniqueTable member:self] == self);
        [_OAFontDescriptorUniqueTable removeObject:self];
#if defined(FONT_DESC_STATS)
        NSLog(@"%lu font descriptors -- removed %p", [_OAFontDescriptorUniqueTable count], self);
#endif
        [_OAFontDescriptorUniqueTableLock unlock];
    }
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if (_font)
        CFRelease(_font);
#else
    [_font release];
#endif
    if (_fontDescriptor)
        CFRelease(_fontDescriptor);
    [_attributes release];
    [super dealloc];
}

- (NSDictionary *)fontAttributes;
{
    return _attributes;
}

//
// All these getters need to look at the desired setting in _attributes and then at the actual matched font otherwise.
//

- (NSString *)family;
{    
    NSString *family = [_attributes objectForKey:(id)kCTFontFamilyNameAttribute];
    if (family)
        return family;
    
    OAFontDescriptorPlatformFont font = self.font;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    return [(id)CTFontCopyFamilyName(font) autorelease];
#else
    return [font familyName];
#endif
}

- (NSString *)fontName;
{    
    NSString *fontName = [_attributes objectForKey:(id)kCTFontNameAttribute];
    if (fontName)
        return fontName;
    
    return [self postscriptName];
}

- (NSString *)postscriptName
{
    OAFontDescriptorPlatformFont font = self.font;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    return [(id)NSMakeCollectable(CTFontCopyPostScriptName(font)) autorelease];
#else
    return [font fontName];
#endif    
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (NSString *)localizedStyleName;
{
    CFStringRef styleName = CTFontCopyLocalizedName([self font], kCTFontStyleNameKey, NULL);
    if (styleName)
        return [(id)NSMakeCollectable(styleName) autorelease];
    
    return nil;
}
#endif

- (CGFloat)size;
{
    NSNumber *fontSize = [_attributes objectForKey:(id)kCTFontSizeAttribute];
    if (fontSize)
        return [fontSize cgFloatValue];
    
    
    OAFontDescriptorPlatformFont font = self.font;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    return CTFontGetSize(font);
#else
    return [font pointSize];
#endif
}

// We return the NSFontManager-style weight here.
- (NSInteger)weight;
{
    // From CTFontTraits.h: "The value returned is a CFNumberRef representing a float value between -1.0 and 1.0 for normalized weight. The value of 0.0 corresponds to the regular or medium font weight."
    
    NSNumber *weightNumber = [[_attributes objectForKey:(id)kCTFontWeightTrait] retain];
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if (!weightNumber) {
        CFDictionaryRef traitDictionary = CTFontCopyTraits(self.font);
        weightNumber = [[(NSDictionary *)traitDictionary objectForKey:(id)kCTFontWeightTrait] retain];
        CFRelease(traitDictionary);
    }
#endif
    
    if (weightNumber) {
        CGFloat weight = [weightNumber cgFloatValue];
        [weightNumber release];
        
        return _weightToFontManagerWeight(weight);
    }
    
    // This will look at the requested symbolic traits if set, and at the traits on the actual matched font if not (allowing us to get YES for "GillSans-Bold" when the traits keys aren't set.
    if ([self bold])
        return 9;
    
    return 5;
}

static CTFontSymbolicTraits _symbolicTraits(OAFontDescriptor *self)
{
    NSDictionary *traits = [self->_attributes objectForKey:(id)kCTFontTraitsAttribute];
    NSNumber *symbolicTraitsNumber = [traits objectForKey:(id)kCTFontSymbolicTrait];
    if (symbolicTraitsNumber) {
        OBASSERT(sizeof(CTFontSymbolicTraits) == sizeof(unsigned int));
        return [symbolicTraitsNumber unsignedIntValue];
    }
    
    OAFontDescriptorPlatformFont font = self.font;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    return CTFontGetSymbolicTraits(font);
#else
    // NSFontTraitMask is NSUInteger; avoid a warning and assert that we aren't dropping anything by the cast.
    NSFontTraitMask result = [[NSFontManager sharedFontManager] traitsOfFont:font];
    OBASSERT(sizeof(CTFontSymbolicTraits) == sizeof(uint32_t));
    OBASSERT(sizeof(result) == sizeof(uint32_t) || result <= UINT32_MAX);
    return (CTFontSymbolicTraits)result;
#endif
}

// NSFontTraitMask and CTFontSymbolicTraits are the same for italic, bold, narrow and fixed-pitch.  Check others before using this for them.
static BOOL _hasSymbolicTrait(OAFontDescriptor *self, unsigned trait)
{
    CTFontSymbolicTraits traits = _symbolicTraits(self);
    return (traits & trait) != 0;
}

- (BOOL)valueForTrait:(uint32_t)trait;
{
    return _hasSymbolicTrait(self, trait);
}

- (BOOL)italic;
{
    return _hasSymbolicTrait(self, kCTFontItalicTrait);
}

- (BOOL)bold;
{
    return _hasSymbolicTrait(self, kCTFontBoldTrait);
}

- (BOOL)condensed;
{
    return _hasSymbolicTrait(self, kCTFontCondensedTrait);
}

- (BOOL)fixedPitch;
{
    return _hasSymbolicTrait(self, kCTFontMonoSpaceTrait);
}

static OAFontDescriptorPlatformFont _copyFont(CTFontDescriptorRef fontDesc, CGFloat size)
{
    //NSLog(@"trying size:%f attributes:%@", size, [(id)CTFontDescriptorCopyAttributes(fontDesc) autorelease]);
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    
#if 0
    CTFontDescriptorRef fontDescriptor = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)_attributes);
    CTFontDescriptorRef matchingDesc = CTFontDescriptorCreateMatchingFontDescriptor(fontDescriptor, NULL);
    CFRelease(fontDescriptor);
    
    CTFontRef font = NULL;
    if (matchingDesc) {
        font = CTFontCreateWithFontDescriptor(fontDesc, size/*size*/, NULL/*matrix*/);
        
    }
#endif
    
    CTFontRef newFont = CTFontCreateWithFontDescriptor(fontDesc, size/*size*/, NULL/*matrix*/);
    
    CFStringRef passedInFamilyName = CTFontDescriptorCopyAttribute(fontDesc, kCTFontFamilyNameAttribute);
    CFStringRef newFontFamilyName = CTFontCopyFamilyName(newFont);
    
    if (passedInFamilyName && ![(NSString *)passedInFamilyName isEqualToString:(NSString *)newFontFamilyName]) {
        // had problems with Zapfino not being created correctly
        if (newFont)
            CFRelease(newFont);
        
        CGFloat fontSizeInDescriptor = size;
        if (fontSizeInDescriptor == 0) {
            NSNumber *fromDescriptor = (NSNumber *)CTFontDescriptorCopyAttribute(fontDesc, kCTFontSizeAttribute);
            fontSizeInDescriptor = rint([fromDescriptor floatValue]); 
            [fromDescriptor release];
        }
        
        newFont = CTFontCreateWithName(passedInFamilyName, fontSizeInDescriptor, NULL);
    }
    
    if (passedInFamilyName)
        CFRelease(passedInFamilyName);
    if (newFontFamilyName)
        CFRelease(newFontFamilyName);
    
    return newFont;

#else
    return [[NSFont fontWithDescriptor:(NSFontDescriptor *)fontDesc size:size] retain];
#endif
}

- (OAFontDescriptorPlatformFont)font;
{
    if (!_font) {
        if (!_fontDescriptor)
            _fontDescriptor = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)_attributes);
        
        CTFontDescriptorRef matchingDesc = NULL;
        
        do {
            if ((_font = _copyFont(_fontDescriptor, 0/*size*/)))
                break;

            // A non-integral size can annoy font lookup.
            CGFloat size = [[_attributes objectForKey:(id)kCTFontSizeAttribute] cgFloatValue];
            CGFloat integralSize = rint(size);
            NSMutableSet *keys = [NSMutableSet setWithArray:[_attributes allKeys]];
            if (size > 0 && size != integralSize) {
                [keys removeObject:(id)kCTFontSizeAttribute];
                if ((_font = _copyFont(_fontDescriptor, integralSize)))
                    break;
            }

            // No direct match -- most likely the traits produce something w/o an exact match (asking for a bold variant of something w/o bold).
            // In OO3's version of this we'd prefer traits to the family. Continue doing so here. We don't have support for maintaining serif-ness, though.
            
            NSMutableDictionary *attributeSubset = [NSMutableDictionary dictionaryWithDictionary:_attributes];
            [attributeSubset removeObjectForKey:(id)kCTFontFamilyNameAttribute];
            [attributeSubset removeObjectForKey:(id)kCTFontNameAttribute];
            
            matchingDesc = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributeSubset);
            if (matchingDesc && (_font = _copyFont(matchingDesc, integralSize)))
                break;
                
            // TODO: Narrow down the traits in the order we want.
            [attributeSubset removeObjectForKey:(id)kCTFontTraitsAttribute];
            matchingDesc = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributeSubset);
            //NSLog(@"keys = %@, matchingDesc = %@", keys, matchingDesc);
            if (matchingDesc && (_font = _copyFont(matchingDesc, integralSize)))
                break;
            
            // baseline fallback?
        } while (0);

        if (matchingDesc)
            CFRelease(matchingDesc);
        
        //NSLog(@"cached font %@ (%@) for attributes %@", _font, CTFontCopyFullName(_font), _attributes);
        OBASSERT(_font);
    }
    
    return _font;
}

#if 0
static OAFontDescriptor *_newWithFontDescriptor(CTFontDescriptorRef desc)
{
    CFDictionaryRef attributes = CTFontDescriptorCopyAttributes(desc);
    OAFontDescriptor *result = [[OAFontDescriptor alloc] initWithFontAttributes:(NSDictionary *)attributes];
    CFRelease(attributes);
    return result;
}
#endif

static OAFontDescriptor *_newWithFontDescriptorHavingTrait(OAFontDescriptor *self, CTFontDescriptorRef desc, uint32_t trait, BOOL value)
{
    CTFontSymbolicTraits oldTraits = _symbolicTraits(self);
    CTFontSymbolicTraits newTraits;
    if (value)
        newTraits = oldTraits | trait;
    else
        newTraits = oldTraits & ~trait;
    
    if (newTraits == oldTraits)
        return [self retain];
    
    NSDictionary *traitsDict = [self->_attributes objectForKey:(id)kCTFontTraitsAttribute];
    NSMutableDictionary *newTraitsDict = traitsDict ? [traitsDict mutableCopy] : [[NSMutableDictionary alloc] init];
    NSMutableDictionary *newAttributes = [self->_attributes mutableCopy];

    [newTraitsDict setObject:[NSNumber numberWithUnsignedInt:newTraits] forKey:(id)kCTFontSymbolicTrait];
    [newAttributes setObject:newTraitsDict forKey:(id)kCTFontTraitsAttribute];
    [newTraitsDict release];
    
    // Make sure we're looking for the new font by its family name, or we won't find Helvetica-Bold
    [newAttributes removeObjectForKey:(id)kCTFontNameAttribute];
    [newAttributes setObject:[self family] forKey:(id)kCTFontFamilyNameAttribute];

    OAFontDescriptor *result = [[OAFontDescriptor alloc] initWithFontAttributes:newAttributes];
    [newAttributes release];
    
    return result;
}

// TODO: These should match most strongly on the indicated attribute, but the current code just tosses it in on equal footing with our regular matching rules.
- (OAFontDescriptor *)newFontDescriptorWithFamily:(NSString *)family;
{
    if ([family isEqualToString:self.family])
        return [self retain];
    
    [self font]; // make sure we have cached our descriptor
    
    NSMutableDictionary *newAttributes = [_attributes mutableCopy];
    [newAttributes setObject:family forKey:(id)kCTFontFamilyNameAttribute];
    
    // remove other names of fonts so that our family choice will win over these.
    [newAttributes removeObjectForKey:(id)kCTFontNameAttribute];
    [newAttributes removeObjectForKey:(id)kCTFontDisplayNameAttribute];
    [newAttributes removeObjectForKey:(id)kCTFontStyleNameAttribute];
    
    // If we don't have traits explicitly listed already, and our original font *did* have traits then add a request. This can happen when the original attributes dictionary had a specific font name ("HelveticaNeue-Bold") instead of a family and traits.
    if ([(NSDictionary *)[newAttributes objectForKey:(id)kCTFontTraitsAttribute] objectForKey:(id)kCTFontSymbolicTrait] == nil) {
        CTFontSymbolicTraits oldTraits = _symbolicTraits(self);
        if (oldTraits) {
            NSDictionary *traitsDict = [newAttributes objectForKey:(id)kCTFontTraitsAttribute];
            NSMutableDictionary *newTraitsDict = traitsDict ? [traitsDict mutableCopy] : [[NSMutableDictionary alloc] init];
            
            [newTraitsDict setObject:[NSNumber numberWithUnsignedInt:oldTraits] forKey:(id)kCTFontSymbolicTrait];
            [newAttributes setObject:newTraitsDict forKey:(id)kCTFontTraitsAttribute];
            [newTraitsDict release];
        }
    }
    
    OAFontDescriptor *result = [[OAFontDescriptor alloc] initWithFontAttributes:newAttributes];
    [newAttributes release];

    return result;
}

- (OAFontDescriptor *)newFontDescriptorWithSize:(CGFloat)size;
{
    if (size == self.size)
        return [self retain];
    
    [self font]; // make sure we have cached our descriptor
    
    NSMutableDictionary *newAttributes = [_attributes mutableCopy];
    [newAttributes setObject:[NSNumber numberWithDouble:size] forKey:(id)kCTFontSizeAttribute];
    OAFontDescriptor *result = [[OAFontDescriptor alloc] initWithFontAttributes:newAttributes];
    [newAttributes release];
    
    return result;
}

- (OAFontDescriptor *)newFontDescriptorWithWeight:(NSInteger)weight;
{
    if (weight == self.weight)
        return [self retain];
    
    [self font]; // make sure we have cached our descriptor
    
    // OBFinishPorting
    CGFloat normalizedWeight = _fontManagerWeightToWeight(weight);
#if 0
    NSFontDescriptor *desc = [(NSFontDescriptor *)_fontDescriptor fontDescriptorByAddingAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:normalizedWeight] forKey:NSFontWeightTrait]];
#endif

    return _newWithFontDescriptorHavingTrait(self, _fontDescriptor, kCTFontBoldTrait, (normalizedWeight > 0));
}

- (OAFontDescriptor *)newFontDescriptorWithValue:(BOOL)value forTrait:(uint32_t)trait;
{
    [self font]; // make sure we have cached our descriptor
    return _newWithFontDescriptorHavingTrait(self, _fontDescriptor, trait, value);
}

- (OAFontDescriptor *)newFontDescriptorWithBold:(BOOL)flag;
{
    return [self newFontDescriptorWithValue:flag forTrait:kCTFontBoldTrait];
}

- (OAFontDescriptor *)newFontDescriptorWithItalic:(BOOL)flag;
{
    return [self newFontDescriptorWithValue:flag forTrait:kCTFontItalicTrait];
}

- (OAFontDescriptor *)newFontDescriptorWithCondensed:(BOOL)flag;
{
    return [self newFontDescriptorWithValue:flag forTrait:kCTFontCondensedTrait];
}

// Report the attributes of the font we actually matched on. Mostly for debugging.
- (NSDictionary *)matchedAttributes;
{
    [self font]; // make sure we have cached our descriptor
    
    CFDictionaryRef attributes = CTFontDescriptorCopyAttributes(_fontDescriptor);
    return [(id)NSMakeCollectable(attributes) autorelease];
}

#pragma mark -
#pragma mark Comparison

- (NSUInteger)hash;
{
    return [_attributes hash];
}

- (BOOL)isEqual:(id)otherObject;
{
    if (self == otherObject)
        return YES;
    if (!otherObject)
        return NO;
    if (![otherObject isKindOfClass:[OAFontDescriptor class]])
        return NO;

    OAFontDescriptor *otherDesc = (OAFontDescriptor *)otherObject;
    return [_attributes isEqual:otherDesc->_attributes];
}

#pragma mark -
#pragma mark NSCopying protocol

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];
}

#pragma mark -
#pragma mark Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [super debugDictionary];

    [dict setObject:_attributes forKey:@"attributes"];
    if (_fontDescriptor)
        [dict setObject:(id)_fontDescriptor forKey:@"fontDescriptor"];
    if (_font)
        [dict setObject:(id)_font forKey:@"font"];
    return dict;
    
}

#pragma mark -
#pragma mark Private

- (void)_invalidateCachedFont;
{
    OBPRECONDITION(_isUniquedInstance);
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if (_font) {
        CFRelease(_font);
        _font = NULL;
    }
#else
    [_font release];
    _font = nil;
#endif
    if (_fontDescriptor) {
        CFRelease(_fontDescriptor);
        _fontDescriptor = NULL;
    }
}

@end
