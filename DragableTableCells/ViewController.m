//
//  ViewController.m
//
//  Anders Borum @palmin
//
// The MIT License (MIT)
//
// Copyright (c) 2016 Anders Borum
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "ViewController.h"
#import "AB_DragableTable.h"

@interface ViewController () <AB_DragableContainerDelegate> {
    NSMutableArray* titles;
    NSMutableArray* images;
}

@end

@implementation ViewController

#pragma mark AB_DragableContainerDelegate

-(UITableView*)dragableContainerView {
    return self.tableView;
}

// quick check if can be entered
-(BOOL)isDragCellRelevant:(UITableViewCell*)cell {
    return YES;
}

// To avoid having duplicates in the stack of view controllers, we
// must be able to check if cell will end up as some specific target.
// This should not have expensive code.
-(BOOL)isCell:(UITableViewCell*)cell equivalentToTarget:(UIViewController<AB_DragableContainerDelegate>*)target {
    // Normally you would use some kind of identifier for the data-type used by both cells and view controllers,
    // but with this random data we identify cells and view-controllers with text
    return [cell.textLabel.text isEqualToString:target.title];
}

// Creates and initializes view-controller representing the content of the given cell.
// Used when dragging cells deeper into the table hierarchy.
// New instances of view-controllers are needed, even though you have existing at hand.
// Method is called on the view controller containing cell.
-(UIViewController<AB_DragableContainerDelegate>*)dragTargetViewControllerFromCell:(UITableViewCell*)cell {
    
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"table"];
    
    NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
    controller.title = titles[indexPath.row];
    return controller;
}

// Creates and initializes view-controller representing existing view controller.
// Used when dragging cells out if the hierarchy through the back button.
// New instances of view-controllers are needed, even though you have existing at hand.
-(UIViewController<AB_DragableContainerDelegate>*)dragTargetViewController:(UIViewController<AB_DragableContainerDelegate>*)vc {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"table"];
    controller.title = vc.title;
    return controller;
}

// title in navigation bar, when this view-controller is the current one.
-(NSString*)dragTitle {
    return self.title;
}

// Perform result of drag operation. Even if something is wrong the done-block must be called
// or the drag state is never left. Method is called on the view controller where dragging started.
-(void)completeDragOfCell:(UITableViewCell*)cell
                 toTarget:(UIViewController<AB_DragableContainerDelegate>*)viewController
                     done:(void (^ _Nonnull)(void))block {
    // since out data is random and not persistent, we just make callback
    block();
}

#pragma mark -

+(NSString*)randomTitle {
    NSArray* nouns = @[@"exchange",@"planes",@"afterthought",@"ladybug",@"meat",@"snails",@"bomb",@"discussion", @"reward",
                       @"nerve",@"payment",@"walk",@"moon",@"boy",@"shoe",@"cushion",@"car",@"system",@"shop", @"current",
                       @"stamp",@"memory",@"engine",@"sponge",@"arithmetic",@"control",@"scarf",@"visitor",@"idea",@"yard"];
    int index = rand() % nouns.count;
    return nouns[index];
}

+(NSString*)randomImageName {
    NSArray* names = @[@"settings", @"close", @"commit", @"dir", @"dir-status", @"doc", @"file", @"img", @"web",
                       @"link", @"repo-dir", @"repo-list", @"repo-status", @"sound", @"src", @"text", @"video", @"zip"];
    int index = rand() % names.count;
    return names[index];
}

// Create random cell data
-(void)createRandomData {
    titles = [NSMutableArray new];
    images = [NSMutableArray new];
    
    int count = 5 + rand() % 20;
    for(int k = 0; k < count; ++k) {
        NSString* title = [ViewController randomTitle];
        [titles addObject:title];
        
        UIImage* image = [UIImage imageNamed:[ViewController randomImageName]];
        [images addObject:image];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createRandomData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = titles[indexPath.row];
    cell.imageView.image = images[indexPath.row];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    // call this at least once for each cell that is dragable
    [cell registerForDragging];

    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"table"];
    
    controller.title = titles[indexPath.row];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
