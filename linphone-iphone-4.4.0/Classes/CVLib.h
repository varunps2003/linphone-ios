

#ifndef CVLib_h
#define CVLib_h
#define APPNAME @"BDL"
#define CV_TRANSPORT @"TCP"
#define CV_DOMAIN @"switch.biznessdial.com"
#define CV_SBC @"sbc.biznessdial.com"
#define SetDefaultValue(value,key)             [[NSUserDefaults standardUserDefaults] setObject:value forKey:key], [[NSUserDefaults standardUserDefaults] synchronize]
#define GetDefaultValue(key)                   [[NSUserDefaults standardUserDefaults] valueForKey:key]
#define RemoveDefaultValue(key)                [[NSUserDefaults standardUserDefaults] removeObjectForKey:key], [[NSUserDefaults standardUserDefaults] synchronize]

#define SetDefaultBoolValue(value,key)             [[NSUserDefaults standardUserDefaults] setBool:value forKey:key], [[NSUserDefaults standardUserDefaults] synchronize]

#endif /* CVLib_h */
