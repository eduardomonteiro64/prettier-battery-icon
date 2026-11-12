#import "LocalizationManager.h"

NSString * const kPBLocalizationDidChangeNotification = @"PBLocalizationDidChangeNotification";
NSString * const kPBLanguagePrefKey = @"PrettierBattery_Language";

@interface LocalizationManager ()
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *translations;
@end

@implementation LocalizationManager

+ (instancetype)sharedManager {
    static LocalizationManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initTranslations];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedLang = [defaults stringForKey:kPBLanguagePrefKey];
        if (savedLang && savedLang.length > 0) {
            _languageCode = [savedLang copy];
        } else {
            _languageCode = @"system";
        }
    }
    return self;
}

+ (NSString *)detectSystemLanguage {
    NSArray<NSString *> *languages = [NSLocale preferredLanguages];
    for (NSString *lang in languages) {
        NSString *lower = [lang lowercaseString];
        if ([lower hasPrefix:@"pt"]) {
            return @"pt-BR";
        } else if ([lower hasPrefix:@"es"]) {
            return @"es";
        } else if ([lower hasPrefix:@"en"]) {
            return @"en";
        }
    }
    return @"en";
}

- (NSString *)effectiveLanguageCode {
    if ([self.languageCode isEqualToString:@"system"] || !self.languageCode) {
        return [LocalizationManager detectSystemLanguage];
    }
    return self.languageCode;
}

- (void)setLanguageCode:(NSString *)languageCode {
    if (!languageCode || languageCode.length == 0) {
        languageCode = @"system";
    }
    if (![_languageCode isEqualToString:languageCode]) {
        _languageCode = [languageCode copy];
        [[NSUserDefaults standardUserDefaults] setObject:_languageCode forKey:kPBLanguagePrefKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kPBLocalizationDidChangeNotification object:self];
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)supportedLanguages {
    NSString *effective = self.effectiveLanguageCode;
    NSString *detectedName = @"English";
    if ([effective isEqualToString:@"pt-BR"]) {
        detectedName = @"Português (Brasil)";
    } else if ([effective isEqualToString:@"es"]) {
        detectedName = @"Español";
    }
    
    NSString *systemTitle = [NSString stringWithFormat:self.translations[@"System Default (%@)"][effective] ?: @"System Default (%@)", detectedName];

    return @[
        @{ @"code": @"system", @"name": systemTitle },
        @{ @"code": @"en",     @"name": @"English" },
        @{ @"code": @"pt-BR",  @"name": @"Português (Brasil)" },
        @{ @"code": @"es",     @"name": @"Español" }
    ];
}

- (NSString *)localizedStringForKey:(NSString *)key {
    if (!key) return @"";
    
    NSString *effective = self.effectiveLanguageCode;
    NSDictionary<NSString *, NSString *> *dict = self.translations[key];
    if (dict) {
        NSString *translated = dict[effective];
        if (translated) {
            return translated;
        }
        if (dict[@"en"]) {
            return dict[@"en"];
        }
    }
    
    return key;
}

- (void)initTranslations {
    self.translations = @{
        // App name & tooltips
        @"Prettier Battery": @{
            @"en": @"Prettier Battery",
            @"pt-BR": @"Prettier Battery",
            @"es": @"Prettier Battery"
        },
        
        // Low Power Mode
        @"Low Power Mode": @{
            @"en": @"Low Power Mode",
            @"pt-BR": @"Modo Pouca Energia",
            @"es": @"Modo de Bajo Consumo"
        },
        @"Could Not Toggle Low Power Mode": @{
            @"en": @"Could Not Toggle Low Power Mode",
            @"pt-BR": @"Não Foi Possível Alternar o Modo Pouca Energia",
            @"es": @"No Se Pudo Cambiar el Modo de Bajo Consumo"
        },
        
        // Battery Statistics
        @"Battery Statistics": @{
            @"en": @"Battery Statistics",
            @"pt-BR": @"Estatísticas da Bateria",
            @"es": @"Estadísticas de la Batería"
        },
        @"Battery Health: %ld%% (%@)": @{
            @"en": @"Battery Health: %ld%% (%@)",
            @"pt-BR": @"Saúde da Bateria: %ld%% (%@)",
            @"es": @"Salud de la Batería: %ld%% (%@)"
        },
        @"Battery Health: Calculating...": @{
            @"en": @"Battery Health: Calculating...",
            @"pt-BR": @"Saúde da Bateria: Calculando...",
            @"es": @"Salud de la Batería: Calculando..."
        },
        @"Capacity: %ld / %ld mAh (%ld%%)": @{
            @"en": @"Capacity: %ld / %ld mAh (%ld%%)",
            @"pt-BR": @"Capacidade: %ld / %ld mAh (%ld%%)",
            @"es": @"Capacidad: %ld / %ld mAh (%ld%%)"
        },
        @"Capacity: %ld mAh": @{
            @"en": @"Capacity: %ld mAh",
            @"pt-BR": @"Capacidade: %ld mAh",
            @"es": @"Capacidad: %ld mAh"
        },
        @"Cycle Count: %ld": @{
            @"en": @"Cycle Count: %ld",
            @"pt-BR": @"Contagem de Ciclos: %ld",
            @"es": @"Número de Ciclos: %ld"
        },
        @"Temperature: %.1f °C": @{
            @"en": @"Temperature: %.1f °C",
            @"pt-BR": @"Temperatura: %.1f °C",
            @"es": @"Temperatura: %.1f °C"
        },
        @"Power Draw: %.1f W (%@)": @{
            @"en": @"Power Draw: %.1f W (%@)",
            @"pt-BR": @"Consumo: %.1f W (%@)",
            @"es": @"Consumo: %.1f W (%@)"
        },
        @"Charge Rate: %.1f W (%@)": @{
            @"en": @"Charge Rate: %.1f W (%@)",
            @"pt-BR": @"Taxa de Carga: %.1f W (%@)",
            @"es": @"Tasa de Carga: %.1f W (%@)"
        },
        @"Power Draw / Rate: %.1f W": @{
            @"en": @"Power Draw / Rate: %.1f W",
            @"pt-BR": @"Consumo / Potência: %.1f W",
            @"es": @"Consumo / Potencia: %.1f W"
        },
        @"Voltage: %.2f V": @{
            @"en": @"Voltage: %.2f V",
            @"pt-BR": @"Tensão: %.2f V",
            @"es": @"Voltaje: %.2f V"
        },
        @"Voltage: %.2f V (%.0f mA)": @{
            @"en": @"Voltage: %.2f V (%.0f mA)",
            @"pt-BR": @"Tensão: %.2f V (%.0f mA)",
            @"es": @"Voltaje: %.2f V (%.0f mA)"
        },
        @"Power Source: %@": @{
            @"en": @"Power Source: %@",
            @"pt-BR": @"Fonte de Energia: %@",
            @"es": @"Fuente de Alimentación: %@"
        },
        @"Power Source: %@ (%ld W)": @{
            @"en": @"Power Source: %@ (%ld W)",
            @"pt-BR": @"Fonte de Energia: %@ (%ld W)",
            @"es": @"Fuente de Alimentación: %@ (%ld W)"
        },
        @"Hardware: %@ (Serial: %@)": @{
            @"en": @"Hardware: %@ (Serial: %@)",
            @"pt-BR": @"Hardware: %@ (Serial: %@)",
            @"es": @"Hardware: %@ (Serial: %@)"
        },
        @"Serial: %@": @{
            @"en": @"Serial: %@",
            @"pt-BR": @"Número de Série: %@",
            @"es": @"Número de Serie: %@"
        },
        
        // Conditions
        @"Normal": @{
            @"en": @"Normal",
            @"pt-BR": @"Normal",
            @"es": @"Normal"
        },
        @"Service Recommended": @{
            @"en": @"Service Recommended",
            @"pt-BR": @"Reparo Recomendado",
            @"es": @"Mantenimiento Recomendado"
        },
        @"Fair": @{
            @"en": @"Fair",
            @"pt-BR": @"Aceitável",
            @"es": @"Aceptable"
        },
        @"Poor": @{
            @"en": @"Poor",
            @"pt-BR": @"Ruim",
            @"es": @"Deficiente"
        },
        
        // Power Sources
        @"Power Adapter (AC)": @{
            @"en": @"Power Adapter (AC)",
            @"pt-BR": @"Adaptador de Energia (AC)",
            @"es": @"Adaptador de Corriente (CA)"
        },
        @"Internal Battery": @{
            @"en": @"Internal Battery",
            @"pt-BR": @"Bateria Interna",
            @"es": @"Batería Interna"
        },
        @"Battery": @{
            @"en": @"Battery",
            @"pt-BR": @"Bateria",
            @"es": @"Batería"
        },
        
        // Color Scheme Submenu
        @"Color Scheme": @{
            @"en": @"Color Scheme",
            @"pt-BR": @"Esquema de Cores",
            @"es": @"Esquema de Color"
        },
        @"Dynamic (Green / Yellow / Red)": @{
            @"en": @"Dynamic (Green / Yellow / Red)",
            @"pt-BR": @"Dinâmico (Verde / Amarelo / Vermelho)",
            @"es": @"Dinámico (Verde / Amarillo / Rojo)"
        },
        @"Native Monochrome (Auto Light/Dark)": @{
            @"en": @"Native Monochrome (Auto Light/Dark)",
            @"pt-BR": @"Monocromático Nativo (Claro/Escuro Auto)",
            @"es": @"Monocromático Nativo (Claro/Oscuro Auto)"
        },
        
        // Menu Bar Display Submenu
        @"Menu Bar Display": @{
            @"en": @"Menu Bar Display",
            @"pt-BR": @"Exibição na Barra de Menus",
            @"es": @"Visualización en la Barra de Menús"
        },
        @"Icon Only": @{
            @"en": @"Icon Only",
            @"pt-BR": @"Apenas Ícone",
            @"es": @"Solo Ícono"
        },
        @"Icon + Percentage": @{
            @"en": @"Icon + Percentage",
            @"pt-BR": @"Ícone + Porcentagem",
            @"es": @"Ícono + Porcentaje"
        },
        @"Icon + Time Remaining": @{
            @"en": @"Icon + Time Remaining",
            @"pt-BR": @"Ícone + Tempo Restante",
            @"es": @"Ícono + Tiempo Restante"
        },
        @"Percentage Only": @{
            @"en": @"Percentage Only",
            @"pt-BR": @"Apenas Porcentagem",
            @"es": @"Solo Porcentaje"
        },
        
        // Language Submenu
        @"Language": @{
            @"en": @"Language",
            @"pt-BR": @"Idioma",
            @"es": @"Idioma"
        },
        @"System Default (%@)": @{
            @"en": @"System Default (%@)",
            @"pt-BR": @"Padrão do Sistema (%@)",
            @"es": @"Predeterminado del Sistema (%@)"
        },
        @"System Default": @{
            @"en": @"System Default",
            @"pt-BR": @"Padrão do Sistema",
            @"es": @"Predeterminado del Sistema"
        },
        @"English": @{
            @"en": @"English",
            @"pt-BR": @"English (Inglês)",
            @"es": @"English (Inglés)"
        },
        @"Portuguese (Brazil)": @{
            @"en": @"Portuguese (Brazil)",
            @"pt-BR": @"Português (Brasil)",
            @"es": @"Portugués (Brasil)"
        },
        @"Spanish": @{
            @"en": @"Spanish",
            @"pt-BR": @"Español (Espanhol)",
            @"es": @"Español"
        },
        
        // General Actions
        @"Launch at Login": @{
            @"en": @"Launch at Login",
            @"pt-BR": @"Iniciar no Login",
            @"es": @"Abrir al Iniciar Sesión"
        },
        @"How to Hide Default macOS Battery...": @{
            @"en": @"How to Hide Default macOS Battery...",
            @"pt-BR": @"Como Ocultar a Bateria Padrão do macOS...",
            @"es": @"Cómo Ocultar la Batería Predeterminada de macOS..."
        },
        @"System Battery Settings...": @{
            @"en": @"System Battery Settings...",
            @"pt-BR": @"Ajustes de Bateria do Sistema...",
            @"es": @"Configuración de Batería del Sistema..."
        },
        @"Quit Prettier Battery": @{
            @"en": @"Quit Prettier Battery",
            @"pt-BR": @"Encerrar Prettier Battery",
            @"es": @"Salir de Prettier Battery"
        },
        
        // Header & State Strings
        @"Fully Charged (Power Adapter)": @{
            @"en": @"Fully Charged (Power Adapter)",
            @"pt-BR": @"Carga Completa (Adaptador de Energia)",
            @"es": @"Carga Completa (Adaptador de Corriente)"
        },
        @"Charging on AC Power": @{
            @"en": @"Charging on AC Power",
            @"pt-BR": @"Carregando na Tomada",
            @"es": @"Cargando en Corriente CA"
        },
        @"Connected to Power (Not Charging)": @{
            @"en": @"Connected to Power (Not Charging)",
            @"pt-BR": @"Conectado à Energia (Sem Carregar)",
            @"es": @"Conectado a la Corriente (Sin Cargar)"
        },
        @"On Battery Power": @{
            @"en": @"On Battery Power",
            @"pt-BR": @"Em Uso da Bateria",
            @"es": @"Usando la Batería"
        },
        
        // Time Remaining Strings
        @"Fully Charged": @{
            @"en": @"Fully Charged",
            @"pt-BR": @"Carga Completa",
            @"es": @"Carga Completa"
        },
        @"Calculating charge time...": @{
            @"en": @"Calculating charge time...",
            @"pt-BR": @"Calculando tempo de carga...",
            @"es": @"Calculando tiempo de carga..."
        },
        @"Calculating time remaining...": @{
            @"en": @"Calculating time remaining...",
            @"pt-BR": @"Calculando tempo restante...",
            @"es": @"Calculando tiempo restante..."
        },
        @"%ldh %02ldm until 100%%": @{
            @"en": @"%ldh %02ldm until 100%%",
            @"pt-BR": @"%ldh %02ldm até 100%%",
            @"es": @"%ldh %02ldm hasta 100%%"
        },
        @"%ldm until 100%%": @{
            @"en": @"%ldm until 100%%",
            @"pt-BR": @"%ldm até 100%%",
            @"es": @"%ldm hasta 100%%"
        },
        @"%ldh %02ldm remaining": @{
            @"en": @"%ldh %02ldm remaining",
            @"pt-BR": @"%ldh %02ldm restantes",
            @"es": @"%ldh %02ldm restantes"
        },
        @"%ldm remaining": @{
            @"en": @"%ldm remaining",
            @"pt-BR": @"%ldm restantes",
            @"es": @"%ldm restantes"
        },
        
        // Alerts
        @"How to hide the default macOS battery icon:": @{
            @"en": @"How to hide the default macOS battery icon:",
            @"pt-BR": @"Como ocultar o ícone de bateria padrão do macOS:",
            @"es": @"Cómo ocultar el ícono de batería predeterminado de macOS:"
        },
        @"1. Open 'System Settings' on your Mac.\n2. Go to 'Control Center'.\n3. Scroll down to 'Battery' and select 'Don't Show in Menu Bar'.\n\nNow only the clean Prettier Battery icon will appear in your menu bar!": @{
            @"en": @"1. Open 'System Settings' on your Mac.\n2. Go to 'Control Center'.\n3. Scroll down to 'Battery' and select 'Don't Show in Menu Bar'.\n\nNow only the clean Prettier Battery icon will appear in your menu bar!",
            @"pt-BR": @"1. Abra 'Ajustes do Sistema' no seu Mac.\n2. Acesse 'Central de Controle'.\n3. Role até 'Bateria' e selecione 'Não Mostrar na Barra de Menus'.\n\nAgora apenas o ícone limpo do Prettier Battery aparecerá na sua barra de menus!",
            @"es": @"1. Abre 'Ajustes del Sistema' en tu Mac.\n2. Ve a 'Centro de Control'.\n3. Desplázate hasta 'Batería' y selecciona 'No mostrar en la barra de menús'.\n\n¡Ahora solo aparecerá el ícono limpio de Prettier Battery en tu barra de menús!"
        },
        @"Got it": @{
            @"en": @"Got it",
            @"pt-BR": @"Entendi",
            @"es": @"Entendido"
        },
        @"Open Control Center": @{
            @"en": @"Open Control Center",
            @"pt-BR": @"Abrir Central de Controle",
            @"es": @"Abrir Centro de Control"
        }
    };
}

@end
