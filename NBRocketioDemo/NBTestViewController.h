//
//  NBTestViewController.h
//  NBRocketioDemo
//
//  Created by Fabrice Aneche on 5/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RocketIO.h"

@interface NBTestViewController : UIViewController <RocketIODelegate> {
    int _counter;
}

@property (weak, nonatomic) IBOutlet UITextView *textView;
- (IBAction)buttonAction:(id)sender;



@end
