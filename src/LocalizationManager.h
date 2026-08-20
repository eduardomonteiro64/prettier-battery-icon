#import <Foundation/Foundation.h>

extern NSString * const kPBLocalizationDidChangeNotification;
extern NSString * const kPBLanguagePrefKey;

#define PBLocalizedString(key, comment) [[LocalizationManager sharedManager] localizedStringForKey:(key)]

@interface LocalizationManager : NSObject

@property (nonatomic, copy) NSString *languageCode; // @"system", @"en", @"pt-BR", @"es"
@property (nonatomic, readonly) NSString *effectiveLanguageCode; // @"en", @"pt-BR", @"es"

+ (instancetype)sharedManager;
+ (NSString *)detectSystemLanguage;

- (NSString *)localizedStringForKey:(NSString *)key;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)supportedLanguages;

@end
