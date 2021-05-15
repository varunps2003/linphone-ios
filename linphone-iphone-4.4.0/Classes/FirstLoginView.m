/*
 * Copyright (c) 2010-2020 Belledonne Communications SARL.
 *
 * This file is part of linphone-iphone
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#import "LinphoneManager.h"
#import "FirstLoginView.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import "Utils/XMLRPCHelper.h"
#import "CVLib.h"

@implementation FirstLoginView

#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
	if (compositeDescription == nil) {
		compositeDescription = [[UICompositeViewDescription alloc] init:self.class
															  statusBar:nil
																 tabBar:nil
															   sideMenu:nil
															 fullscreen:false
														 isLeftFragment:YES
														   fragmentWith:nil];
	}
	return compositeDescription;
}

- (UICompositeViewDescription *)compositeViewDescription {
	return self.class.compositeViewDescription;
}

#pragma mark - ViewController Functions

- (void)viewDidLoad {
	[super viewDidLoad];
	NSString *siteUrl =
		[[LinphoneManager instance] lpConfigStringForKey:@"first_login_view_url"] ?: @"http://www.linphone.org";
	[_siteButton setTitle:siteUrl forState:UIControlStateNormal];
    _domainField.text = CV_DOMAIN;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	// Set observer
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(registrationUpdateEvent:)
												 name:kLinphoneRegistrationUpdate
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(configureStateUpdateEvent:)
												 name:kLinphoneConfiguringStateUpdate
											   object:nil];

	// Update on show
	const MSList *list = linphone_core_get_proxy_config_list([LinphoneManager getLc]);
	if (list != NULL) {
		LinphoneProxyConfig *config = (LinphoneProxyConfig *)list->data;
		if (config) {
			[self registrationUpdate:linphone_proxy_config_get_state(config)];
		}
	}

	if (account_creator) {
		linphone_account_creator_unref(account_creator);
	}
	NSString *siteUrl =
		[[LinphoneManager instance] lpConfigStringForKey:@"first_login_view_url"] ?: @"http://www.linphone.org";
	account_creator = linphone_account_creator_new([LinphoneManager getLc], siteUrl.UTF8String);

	[_usernameField
		showError:[AssistantView
					  errorForLinphoneAccountCreatorUsernameStatus:LinphoneAccountCreatorUsernameStatusInvalid]
			 when:^BOOL(NSString *inputEntry) {
			   LinphoneAccountCreatorUsernameStatus s =
				   linphone_account_creator_set_username(account_creator, inputEntry.UTF8String);
			   _usernameField.errorLabel.text = [AssistantView errorForLinphoneAccountCreatorUsernameStatus:s];
			   return s != LinphoneAccountCreatorUsernameStatusOk;
			 }];

	[_passwordField
		showError:[AssistantView
					  errorForLinphoneAccountCreatorPasswordStatus:LinphoneAccountCreatorPasswordStatusTooShort]
			 when:^BOOL(NSString *inputEntry) {
			   LinphoneAccountCreatorPasswordStatus s =
				   linphone_account_creator_set_password(account_creator, inputEntry.UTF8String);
			   _passwordField.errorLabel.text = [AssistantView errorForLinphoneAccountCreatorPasswordStatus:s];
			   return s != LinphoneAccountCreatorUsernameStatusOk;
			 }];

	[_domainField
		showError:[AssistantView errorForLinphoneAccountCreatorDomainStatus:LinphoneAccountCreatorDomainInvalid]
			 when:^BOOL(NSString *inputEntry) {
			   LinphoneAccountCreatorDomainStatus s =
				   linphone_account_creator_set_domain(account_creator, inputEntry.UTF8String);
			   _domainField.errorLabel.text = [AssistantView errorForLinphoneAccountCreatorDomainStatus:s];
			   return s != LinphoneAccountCreatorDomainOk;
			 }];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	// Remove observer
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kLinphoneRegistrationUpdate object:nil];
}

- (void)shouldEnableNextButton {
	BOOL invalidInputs = NO;
	for (UIAssistantTextField *field in @[ _usernameField, _passwordField, _domainField ]) {
		invalidInputs |= (field.isInvalid || field.lastText.length == 0);
	}
	_loginButton.enabled = !invalidInputs;
}

#pragma mark - Event Functions

- (void)configureStateUpdateEvent:(NSNotification *)notif {
	LinphoneConfiguringState state = [[notif.userInfo objectForKey:@"state"] intValue];
	switch (state) {
		case LinphoneConfiguringFailed: {
			[_waitView setHidden:true];
			UIAlertController *errView = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Configuration failed", nil)
																			 message:NSLocalizedString(@"Cannot retrieve your configuration. Please check credentials or try again later", nil)
																	  preferredStyle:UIAlertControllerStyleAlert];
			
			UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
																	style:UIAlertActionStyleDefault
																  handler:^(UIAlertAction * action) {}];
			
			[errView addAction:defaultAction];
			[self presentViewController:errView animated:YES completion:nil];
			linphone_core_set_provisioning_uri([LinphoneManager getLc], NULL);
			break;
		}
		default:
			break;
	}
	if (account_creator) {
		linphone_account_creator_unref(account_creator);
	}
	NSString *siteUrl =
		[[LinphoneManager instance] lpConfigStringForKey:@"first_login_view_url"] ?: @"http://www.linphone.org";
	account_creator = linphone_account_creator_new([LinphoneManager getLc], siteUrl.UTF8String);
}

- (void)registrationUpdateEvent:(NSNotification *)notif {
	[self registrationUpdate:[[notif.userInfo objectForKey:@"state"] intValue]];
}

- (void)registrationUpdate:(LinphoneRegistrationState)state {
	switch (state) {
		case LinphoneRegistrationOk: {
			[[LinphoneManager instance] lpConfigSetBool:FALSE forKey:@"enable_first_login_view_preference"];
			[_waitView setHidden:true];
			[PhoneMainView.instance changeCurrentView:DialerView.compositeViewDescription];
			break;
		}
		case LinphoneRegistrationNone:
		case LinphoneRegistrationCleared: {
			[_waitView setHidden:true];
			break;
		}
		case LinphoneRegistrationFailed: {
			[_waitView setHidden:true];
			break;
		}
		case LinphoneRegistrationProgress: {
			[_waitView setHidden:false];
			break;
		}
		default:
			break;
	}
}

#pragma mark - Action Functions

- (void)onSiteClick:(id)sender {
	NSURL *url = [NSURL URLWithString:_siteButton.titleLabel.text];
	[[UIApplication sharedApplication] openURL:url];
	return;
}

- (void)onLoginClick:(id)sender {
	if (!linphone_core_is_network_reachable(LC)) {
        [PhoneMainView.instance presentViewController:[LinphoneUtils networkErrorView] animated:YES completion:nil];
		return;
	}
	        
    NSString *username = _usernameField.text;
    NSString *password = _passwordField.text;
    
    if ([username length] < 1)
    {
        UIAlertView *alertView=[[UIAlertView alloc] initWithTitle:APPNAME message:@"User Name" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
        [alertView show];
        return;
    }
    
    if ([password length] < 1)
    {
        UIAlertView *alertView=[[UIAlertView alloc] initWithTitle:APPNAME message:@"Enter Password" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
        [alertView show];
        return;
    }
    
    SetDefaultValue(username, @"CVUSERNAME");
    SetDefaultValue(password, @"CVPASSWORD");
    _waitView.hidden = NO;
    [self HLogin];
        
    /*if ([GetDefaultValue(kRememberMe) integerValue] == 1) {
        SetDefaultValue(ShareObj.userName, kRememberUserName);
        SetDefaultValue(ShareObj.passWord, kRememberPassWord);
    }
    else {
        RemoveDefaultValue(kRememberUserName);
        RemoveDefaultValue(kRememberPassWord);
    }*/
    
    
}

- (void)HLogin {
    
    
    LinphoneProxyConfig *config = linphone_core_create_proxy_config(LC);
    LinphoneAddress *addr = linphone_address_new(NULL);
    LinphoneAddress *tmpAddr = linphone_address_new([NSString stringWithFormat:@"sip:%@",CV_DOMAIN].UTF8String);
    if (tmpAddr == nil) {
        NSLog(@"Configuration Error");
        return;
    }
    
    linphone_address_set_username(addr, [NSString stringWithFormat:@"%@",GetDefaultValue(@"CVUSERNAME")].UTF8String);
    linphone_address_set_port(addr, linphone_address_get_port(tmpAddr));
    linphone_address_set_domain(addr, linphone_address_get_domain(tmpAddr));
    linphone_address_set_display_name(addr, [NSString stringWithFormat:@"%@",GetDefaultValue(@"CVUSERNAME")].UTF8String);
    linphone_proxy_config_set_identity_address(config, addr);
    
    // set transport
    linphone_proxy_config_set_route(
            config,
                                    [NSString stringWithFormat:@"%s;transport=%s",CV_DOMAIN.UTF8String, CV_TRANSPORT.lowercaseString.UTF8String]
                .UTF8String);
        linphone_proxy_config_set_server_addr(
            config,
            [NSString stringWithFormat:@"%s;transport=%s", CV_SBC.UTF8String, CV_TRANSPORT.lowercaseString.UTF8String]
                .UTF8String);

    linphone_proxy_config_enable_publish(config, FALSE);
    linphone_proxy_config_enable_register(config, TRUE);
    linphone_proxy_config_set_expires(config, 30);
    //linphone_nat_policy_set_stun_server(config,@"stun.l.google.com:19302");
    linphone_proxy_config_set_push_notification_allowed(config,false);
    

    LinphoneAuthInfo *info =
        linphone_auth_info_new(linphone_address_get_username(addr), // username
                               NULL,                                // user id
                               [NSString stringWithFormat:@"%@",GetDefaultValue(@"CVPASSWORD")].UTF8String,                        // passwd
                               NULL,                                // ha1
                               linphone_address_get_domain(addr),   // realm - assumed to be domain
                               linphone_address_get_domain(addr)    // domain
                               );
    linphone_core_add_auth_info(LC, info);
    linphone_address_unref(addr);
    linphone_address_unref(tmpAddr);

    if (config) {
        [[LinphoneManager instance] configurePushTokenForProxyConfig:config];
        if (linphone_core_add_proxy_config(LC, config) != -1) {
            linphone_core_set_default_proxy_config(LC, config);
            // reload address book to prepend proxy config domain to contacts' phone number
            // todo: STOP doing that!
            [[LinphoneManager.instance fastAddressBook] fetchContactsInBackGroundThread];
            //[PhoneMainView.instance changeCurrentView:AssistantView.compositeViewDescription];
            [PhoneMainView.instance changeCurrentView:DialerView.compositeViewDescription];
        } else {
          NSLog(@"Configuration Error");
        }
    } else {
        NSLog(@"Configuration Error");
    }
}

#pragma mark - UITextFieldDelegate Functions

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	if (textField.returnKeyType == UIReturnKeyNext) {
		if (textField == _usernameField) {
			[_domainField becomeFirstResponder];
		} else if (textField == _domainField) {
			[_passwordField becomeFirstResponder];
		}
	} else if (textField.returnKeyType == UIReturnKeyDone) {
		[_loginButton sendActionsForControlEvents:UIControlEventTouchUpInside];
	}

	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	UIAssistantTextField *atf = (UIAssistantTextField *)textField;
	[atf textFieldDidEndEditing:atf];
}

- (BOOL)textField:(UITextField *)textField
	shouldChangeCharactersInRange:(NSRange)range
				replacementString:(NSString *)string {
	UIAssistantTextField *atf = (UIAssistantTextField *)textField;
	[atf textField:atf shouldChangeCharactersInRange:range replacementString:string];
	[self shouldEnableNextButton];
	return YES;
}

@end
