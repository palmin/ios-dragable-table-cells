//
//  AB_Dragable.h
//  WorkingCopy
//
//  Created by Anders Borum on 04/08/16.
//  Copyright © 2016 Applied Phasor. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// UIViewController should implement this protocol to supporting dragging.
// It does not have to be a UITableViewController but it needs a UITableView.
@protocol AB_DragableContainerDelegate

// Table view where cells can be dragged from
-(UITableView*)dragableContainerView;

// quick check if can be entered
-(BOOL)isDragCellRelevant:(UITableViewCell*)cell;

// To avoid having duplicates in the stack of view controllers, we
// must be able to check if cell will end up as some specific target.
// This should not have expensive code.
-(BOOL)isCell:(UITableViewCell*)cell equivalentToTarget:(UIViewController<AB_DragableContainerDelegate>*)target;

// Creates and initializes view-controller representing the content of the given cell.
// Used when dragging cells deeper into the table hierarchy.
// New instances of view-controllers are needed, even though you have existing at hand.
// Method is called on the view controller containing cell.
-(UIViewController<AB_DragableContainerDelegate>*)dragTargetViewControllerFromCell:(UITableViewCell*)cell;

// Creates and initializes view-controller representing existing view controller.
// Used when dragging cells out if the hierarchy through the back button.
// New instances of view-controllers are needed, even though you have existing at hand.
-(UIViewController<AB_DragableContainerDelegate>*)dragTargetViewController:(UIViewController<AB_DragableContainerDelegate>*)vc;

// title in navigation bar, when this view-controller is the current one.
-(NSString*)dragTitle;

// Perform result of drag operation. Even if something is wrong the done-block must be called
// or the drag state is never left. Method is called on the view controller where dragging started.
-(void)completeDragOfCell:(UITableViewCell*)cell
                 toTarget:(UIViewController<AB_DragableContainerDelegate>*)viewController
                     done:(void (^ _Nonnull)(void))block;

@optional

// default is to find assume all view controllers implementing AB_DragableContainerDelegate protocol are relevant
-(BOOL)isViewControllerRelevant:(UIViewController<AB_DragableContainerDelegate>*)viewController;

// if not implemented dragging is always allowed
-(BOOL)draggingAllowed;

@end

@interface UITableViewCell (AB_DragableTable)

// You need to call this on all cells that are dragable, but it is safe to register multiple times.
// Often called in tableView:cellForRowAtIndexPath: or tableView:willDisplayCell:forRowAtIndexPath:
-(void)registerForDragging;

@end

NS_ASSUME_NONNULL_END
