//
//  AB_Dragable.m
//  WorkingCopy
//
//  Created by Anders Borum on 04/08/16.
//  Copyright © 2016 Applied Phasor. All rights reserved.
//

#import <objc/message.h>
#import "AB_DragableTable.h"

// internal short-hand for view controllers supporting drag
typedef UIViewController<AB_DragableContainerDelegate> DragableController;

// we have our own stack of view-controllers and we need to remember which cells
// they are created from to make sure we do not instantiate multiple view controllers
// corresponding to the same location in the hierarchy.
@interface AB_ContainerInfo : NSObject
@property (nonatomic, strong) UIView* view;
@property (nonatomic, strong) DragableController* controller;

@property (nonatomic, assign) BOOL enter; // if not ENTER (going deeper in hierarchy) we leave (step out)
@property (nonatomic, assign) int depth; // depth relative to starting drag controller
@property (nonatomic, strong) NSIndexPath* cellIndexPath; // index path of cell used to enter

// ContainerInfo instances match when they are at the same level
// and created from the same cell index path.
-(BOOL)matching:(AB_ContainerInfo*)other;

@end

@implementation AB_ContainerInfo

-(BOOL)matching:(AB_ContainerInfo*)other {
    if(self.depth != other.depth) return NO;
    if(self.cellIndexPath == other.cellIndexPath) return YES; // handles when both are nil
    return [self.cellIndexPath isEqual:other.cellIndexPath];  // handles when none or one is nil
}

@end

// Helper object for dragable views, making it easier to control when
// object can be dragged, where it can be dragged and helping with
// intra-controller drags.
@interface AB_Dragable : NSObject {
    __weak UITableViewCell* view;
    
    UILongPressGestureRecognizer* longPressRecognizer;
    
    UIView* draggingView;
    
    // set when dragging starts
    DragableController* viewController;
    UINavigationController* nav;
    
    // we make changes to navigationItem, and store old values to let us restore
    NSString* originalTitle;
    NSArray* orignalRightItems;
    
    // view controllers we are showing as part of drag, where last one is the most relevant
    NSMutableArray<AB_ContainerInfo*>* stack;
    NSTimeInterval whenLastEnter; // set when entering (not leaving) to avoid entering multiple times by accident
    
    __weak NSObject* lastTarget;
    CGPoint lastPoint;
}

@end

@implementation AB_Dragable

#pragma mark Configuration

// free space for stacked view controllers
const CGFloat margin = 80;

// we do not enter cells when hovering the leftmost pixels
const CGFloat minimumCellLeft = 100;

// only the left part of UINavigationBar is interpreted as back
const CGFloat maximumBackLeft = 90;

// number of seconds we wait before entering view controller, when file is dragged on cell
const NSTimeInterval enterDelay = 0.55;

// to avoid entering multiple directories by accident, we refuse to enter faster than this
const NSTimeInterval enterAgainDelay = 0.85;

// number of seconds we wait when moving out of consecutive view controllers
const NSTimeInterval exitRepeatDelay = enterDelay * 0.75;

// number of seconds we wait when keeping finger on back button
const NSTimeInterval backRepeatDelay = enterDelay;

#pragma mark -

-(BOOL)dragInProgress {
    return viewController != nil;
}

-(void)clearViewControllerStack {
    for (AB_ContainerInfo* info in stack) {
        [self removeContainer: info];
    }
    [stack removeAllObjects];
}

// setup new dragging operation.
-(void)startDraggingAtPoint:(CGPoint)point {
    [self determineNavController];
    if(!self.dragInProgress) return;
    
    originalTitle = viewController.navigationItem.title;
    orignalRightItems = viewController.navigationItem.rightBarButtonItems;
    
    stack = [NSMutableArray new];
    
    if(draggingView == nil) {
        draggingView = [view snapshotViewAfterScreenUpdates:YES];
        draggingView.layer.shadowPath = [UIBezierPath bezierPathWithRect:draggingView.bounds].CGPath;
        draggingView.layer.shadowRadius = 5;
        draggingView.layer.shadowOffset = CGSizeMake(1, 3);
        draggingView.layer.shadowOpacity = 0.5;
        
        draggingView.frame = [view.window convertRect:view.bounds fromView:view];
        [view.window addSubview:draggingView];
    }
    
    viewController.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:.2 animations:^{
        draggingView.transform = CGAffineTransformMakeScale(0.95, 0.95);
        draggingView.center = point;
        
        viewController.navigationItem.title = viewController.dragTitle;
        viewController.navigationItem.rightBarButtonItems = nil;
    }];
}

// Move out a singe view-controller from the stack, reverse of how it appeared.
// It is not removed from view hierarchy by this method.
-(void)moveOutContainer:(AB_ContainerInfo*)info {
    CGRect frame = info.view.frame;
    
    // left-aligned controllers fly to the left, right-aligned to the right
    BOOL leftAligned = frame.origin.x <= 0.0;
    frame.origin.x = leftAligned ? -frame.size.width : viewController.view.frame.size.width;
    
    info.view.frame = frame;
    info.view.alpha = 0;
}

-(void)removeContainer:(AB_ContainerInfo*)info {
    [info.controller willMoveToParentViewController:nil];
    [info.controller removeFromParentViewController];
    [info.view removeFromSuperview];
    [info.controller didMoveToParentViewController:nil];
}

-(void)moveBackDragging {
    [UIView animateWithDuration:.2 animations:^{
        // move back view controllers
        for (AB_ContainerInfo* info in stack) {
            [self moveOutContainer: info];
        }
        
        draggingView.transform = CGAffineTransformIdentity;
        draggingView.frame = [view.window convertRect:view.bounds fromView:view];
        if(draggingView.alpha > 0.5) {
            draggingView.alpha = 0.5;
        }
        
    } completion:^(BOOL finished) {
        [self clearViewControllerStack];
        
        // restore navigation bar
        viewController.navigationItem.title = originalTitle;
        viewController.navigationItem.rightBarButtonItems = orignalRightItems;
        
        [UIView animateWithDuration:.1 animations:^{
            draggingView.alpha = 0;
            
        } completion:^(BOOL finished) {
            viewController.view.userInteractionEnabled = YES;
            [draggingView removeFromSuperview];
            draggingView = nil;
            
            nav = nil;
            viewController = nil;
        }];
    }];
}

-(void)endDraggingPoint:(CGPoint)point cancel:(BOOL)cancel {
    // make sure we do not enter anything as delayed reaction
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptTargetEnter) object:nil];
    
    if(draggingView == nil) return;
    
    DragableController* current = self.relevantController;
    if(!cancel && current != viewController) {
        [UIView animateWithDuration:1.0 animations:^{
            draggingView.alpha = 0;
        }];
        
        [viewController completeDragOfCell:view toTarget:current done:^{
            [self moveBackDragging];
        }];
    } else {
        [self moveBackDragging];
    }
}

-(instancetype)initWithCell:(UITableViewCell*)cell {
    self = [super init];
    if(self) {
        view = cell;
        
        longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        [view addGestureRecognizer:longPressRecognizer];
        longPressRecognizer.enabled = YES;
    }
    return self;
}

-(void)determineNavController {
    // follow responder chain until we have first UIViewController that has navigation controller
    nav = nil;
    viewController = nil;
    UIResponder* responder = view;
    while(responder != nil) {
        if([responder isKindOfClass:[UIViewController class]] &&
           [responder conformsToProtocol:@protocol(AB_DragableContainerDelegate)]) {
            
            viewController = (UIViewController<AB_DragableContainerDelegate>*)responder;
            
            // make sure dragging is allowed
            if([viewController respondsToSelector:@selector(draggingAllowed)]) {
                if(!viewController.draggingAllowed) viewController = nil;
            }
            
            nav = viewController.navigationController;
            break;
        }
        responder = [responder nextResponder];
    }
}

-(DragableController*)relevantController {
    return stack.lastObject.controller ?: viewController;
}

// point is in window coordinates
-(BOOL)isPoint:(CGPoint)point insideView:(UIView*)theView {
    if(theView == nil) return NO;
    
    CGPoint local = [theView.window convertPoint:point toView:theView];
    return CGRectContainsPoint(theView.bounds, local);
}

// for UITableView there is better way to get sub-views than just the view hierarchy
-(NSArray<UIView*>*)childViewsForView:(UIView*)container {
    if([container isKindOfClass:[UITableView class]]) {
        UITableView* tableView = (UITableView*)container;
        return tableView.visibleCells;
    }
    
    return container.subviews;
}

// Find relevant target at the given point which is in window coordinate system.
// Not only the point is taken into account, but also how much time has gone since
// last change to view controller hierarchy, to avoid making very fast changes.
//
// Check if dragged cell is hovering above:
//   (1) dragged view itself (return cell itself, which means no-drag)
//   (2) cell that can be entered (return cell hovering above),
//   (3) back-button (return view controller back button takes you to) or
//   (4) outside current topmost view controller (return dragged view, that means no-drag)
-(NSObject*)targetViewAtPoint:(CGPoint)point {
    NSObject* target = nil;
    
    DragableController* relevant = self.relevantController;
    if(relevant != viewController) {
        // if point is outside our view, we use self.view as special value to indicate that we might
        // hide this view controller
        BOOL outsideStack = ![self isPoint:point insideView:relevant.view];
        if(outsideStack) {
            BOOL insideOrig =  [self isPoint:point insideView:viewController.dragableContainerView] &&
                              ![self isPoint:point insideView:nav.navigationBar];
            if(insideOrig) return view;

            // we do not look for cells when outside
            relevant = nil;
            
        } else {
            // even if no cells match, the view controller itself does
            target = relevant;
        }
        
    } else {
        // highest priority is view itself, that is always a valid target
        // for when we cancel the drag
        if([self isPoint:point insideView:view]) return view;
    }
    
    // look for cells in relevant tableView to enter directories
    UITableView* tableView = relevant.dragableContainerView;
    for (UITableViewCell* cell in tableView.visibleCells) {
        if([self isPoint:point insideView:cell]) {
            // we do not enter cells when hovering the leftmost pixels
            CGPoint local = [cell.window convertPoint:point toView:cell];
            if(local.x < minimumCellLeft) continue;
            
            // entering view controllers is not allowed at very first after having entered existing view controller
            NSTimeInterval secsSinceEnter = [NSDate timeIntervalSinceReferenceDate] - whenLastEnter;
            if(secsSinceEnter < enterAgainDelay) {
                [self performSelector:@selector(handleDrag) withObject:nil afterDelay:enterAgainDelay - enterDelay];
                return nil;
            }
            
            if([relevant isDragCellRelevant:cell]) return cell;
        }
    }
        
    // look for UINavigationBar where left part means back
    UINavigationBar* bar = nav.navigationBar;
    if([self isPoint:point insideView:bar]) {
        CGPoint local = [bar.window convertPoint:point toView:bar];
        if(local.x <= maximumBackLeft) {
            
            // we want the view-controller that is one step out from current one
            int depth = stack.lastObject.depth - 1;
            if(depth > 0) {
                // look for first time we have this depth in internal stack
                for (AB_ContainerInfo* info in stack.reverseObjectEnumerator) {
                    if(info.depth == depth) {
                        // try again with delay even if no movement
                        [self performSelector:@selector(handleDrag) withObject:nil afterDelay:backRepeatDelay];

                        return info.controller;
                    }
                }
            }
            
            // we need to look in navigation hierarchy
            NSInteger index = nav.viewControllers.count - 1 + depth;
            if(index >= 0 && index < nav.viewControllers.count) {

                UIViewController* vc = nav.viewControllers[index];
                if([vc conformsToProtocol:@protocol(AB_DragableContainerDelegate)]) {
                    BOOL relevant = ![viewController respondsToSelector:@selector(isViewControllerRelevant:)] ||
                                    [viewController isViewControllerRelevant:(DragableController*)vc];
                    if(relevant) {
                        // try again with delay even if no movement
                        [self performSelector:@selector(handleDrag) withObject:nil afterDelay:backRepeatDelay];
                        
                        return vc;
                    }
                }
            }
        }
    }
    
    return target;
}

// Try to enter current target as previously determined by targetViewAtPoint:
//
// There are some different targets that mean different things:
//   (1) dragged view itself (means no-drag and will step towards original view controller)
//   (2) cell that can be entered (create corresponding view-controller and make this top-most),
//   (3) back-button (create view-controller corresponding to back-button, which is itself
//                    represented by view-controller and make this new instance top-most)
//   (4) identical to (1) at this point

-(void)attemptTargetEnter {
    // trying to enter relevant view controller does nothing
    if(lastTarget == nil || lastTarget == self.relevantController) return;
    
    // trying to enter our-selves has special meaning and will pop view controllers from stack
    AB_ContainerInfo* last = stack.lastObject;
    if(lastTarget == view) {
        if(last) {
            [stack removeLastObject];
            
            [UIView animateWithDuration:0.3 animations:^{
                
                [self moveOutContainer: last];
                [self updateViewControllers];

            } completion:^(BOOL finished) {
                
                [self removeContainer: last];
                
                // schedule another removal after some time
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptTargetEnter) object:nil];
                [self performSelector:@selector(attemptTargetEnter) withObject:nil afterDelay:exitRepeatDelay];
            }];
        }
        
        return;
    }
    
    // determine view controller depth and indexPath
    AB_ContainerInfo* info = [AB_ContainerInfo new];
    info.enter = YES;
    BOOL matchesStart = lastTarget == viewController;
    if([lastTarget isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell* cell = (UITableViewCell*)lastTarget;
        info.cellIndexPath = [self.relevantController.dragableContainerView indexPathForCell:cell];
        matchesStart = [viewController isCell:cell equivalentToTarget:viewController];

    } else if([lastTarget isKindOfClass:[UIViewController class]]) {
        info.enter = NO;
    }
    info.depth = last.depth + (info.enter ? 1 : -1); // calculate new depth;

    // check if we already have this on stack
    NSUInteger unwindStart = matchesStart ? 0 : NSNotFound;
    for (AB_ContainerInfo* existing in stack) {
        if(existing.controller == lastTarget || [existing matching:info]) {
            unwindStart = 1 + [stack indexOfObject:existing];
            break;
        }
    }

    // unwind to this match
    if(unwindStart != NSNotFound) {
        NSRange range = NSMakeRange(unwindStart, stack.count - unwindStart);
        NSArray<AB_ContainerInfo*>* unwindThese = [stack subarrayWithRange:range];
        [stack removeObjectsInRange:range];
        
        [UIView animateWithDuration:0.3 animations:^{
            for (AB_ContainerInfo* unwindInfo in unwindThese) {
                [self moveOutContainer: unwindInfo];
            }
            [self updateViewControllers];
        } completion:^(BOOL finished) {
            for (AB_ContainerInfo* unwindInfo in unwindThese) {
                [self removeContainer: unwindInfo];
            }
        }];
        
        return;
    }
    
    // instantiate view controller to add
    DragableController* vc = nil;
    if([lastTarget isKindOfClass:[UITableViewCell class]]) {
        vc = [self.relevantController dragTargetViewControllerFromCell: (UITableViewCell*)lastTarget];

    } else if([lastTarget isKindOfClass:[UIViewController class]]) {
        vc = [self.relevantController dragTargetViewController:(DragableController*)lastTarget];
    }
    vc.view.userInteractionEnabled = NO;
    if(vc == nil) return;
    
    // determine rectangle used for this, in current view controller coordinates
    CGRect rect = viewController.view.bounds;
    CGFloat wid = rect.size.width - margin;

    // whether we slide in from right or left, is only controlled for first view-controller, and the later
    // ones use the same one as the first one
    BOOL fromRight = info.enter;
    AB_ContainerInfo* first = stack.firstObject;
    if(first) fromRight = first.enter;
    
    [vc willMoveToParentViewController:viewController];
    [UIView performWithoutAnimation:^{
        info.view = [[UIView alloc] initWithFrame:CGRectZero];
        [info.view addSubview:vc.view];
        [viewController.view addSubview: info.view];

        info.view.frame = CGRectMake(fromRight ? rect.size.width : -wid, 0, wid, rect.size.height);
        vc.view.frame = info.view.bounds;
        info.view.alpha = 0.5;
        
        info.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:info.view.bounds].CGPath;
        info.view.layer.shadowRadius = 5;
        info.view.layer.shadowOffset = CGSizeMake(-2, 0);
        info.view.layer.shadowOpacity = 0.5;
    }];
    [viewController addChildViewController:vc];
    [vc didMoveToParentViewController:viewController];
    
    info.controller = vc;
    [stack addObject: info];

    [UIView animateWithDuration:0.3 animations:^{
        info.view.alpha = 1;
        [self updateViewControllers];
    } completion:^(BOOL completion) {
        if(info.enter) {
            whenLastEnter = [NSDate timeIntervalSinceReferenceDate];
        }
    }];
}

// Position stack elements such that the topmost is at the edge and the other ones
// are slightly longer from the edge and updates navigation bar title to match topmost.
-(void)updateViewControllers {
    viewController.navigationItem.title = self.relevantController.dragTitle;

    // move existing stack to make room for new one
    CGRect rect = viewController.view.bounds;
    CGFloat wid = rect.size.width - margin;

    // We want offset to go from 0 -> 0.45 * margin such.
    // It is important we never get past 0.5 * margin, since we use distance to edges to
    // determine if view-controller is left or right-aligned.
    CGFloat offset = 0, steps = stack.count;
    CGFloat offsetStep = steps <= 1.0 ? 0.0 : (0.45 * margin / steps);
    
    for (AB_ContainerInfo* info in stack.reverseObjectEnumerator) {
        DragableController* vc = info.controller;
        
        CGFloat distLeft = info.view.frame.origin.x, distRight = rect.size.width - CGRectGetMaxX(info.view.frame);
        BOOL rightMost = distRight < distLeft;
        
        info.view.frame = CGRectMake(rightMost ? (margin - offset) : offset, 0, wid, rect.size.height);
        vc.view.frame = info.view.bounds;
        
        offset += offsetStep;
    }
}

-(void)setCurrentTarget:(NSObject*)target {
    // if target is unchanged for some time, we try to enter
    if(target != lastTarget) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptTargetEnter) object:nil];
        [self performSelector:@selector(attemptTargetEnter) withObject:nil afterDelay:enterDelay];
        lastTarget = target;
    }
}

// Update while dragging with regards to lastPoint which is in window coordinates.
//
// Determines what drag target is below this point and triggers delayed action when
// drag target has been the same for some period of time.
//
// Also scrolls table-view for topmost view-controller when near top or bottom of what is
// visible.
-(void)handleDrag {
    CGPoint point = lastPoint;
    
    // If container is UIScrollView we scroll at the top/bottom borders
    UIView* container = self.relevantController.dragableContainerView;
    if([container isKindOfClass:[UIScrollView class]]) {
        // we make calculations about top/bottom outside scroll-view to not have
        // to worry about the scrolling coordinate system.
        UIScrollView* scrollView = (UIScrollView*)container;
        CGRect frame = scrollView.frame;
        CGPoint local = [view.window convertPoint:point toView:scrollView.superview];
        
        CGPoint contentOffset = scrollView.contentOffset;
        CGFloat ceiling = frame.origin.y + 50, floor = frame.size.height - 50;
        
        if(local.y < ceiling && scrollView.contentOffset.y > 0.0) {
            CGFloat speed = 0.5 * sqrt(ceiling - local.y);
            contentOffset.y = fmax(0, contentOffset.y - speed);
        } else if(local.y > floor && scrollView.contentOffset.y + frame.size.height < scrollView.contentSize.height) {
            CGFloat speed = 0.5 * sqrt(local.y - floor);
            contentOffset.y = fmin(scrollView.contentOffset.y + frame.size.height,
                                   contentOffset.y + speed);
        }

        // if there is scrolling, we schedule update to get smooth scrolling
        // without touch changes.
        if(!CGPointEqualToPoint(scrollView.contentOffset, contentOffset)) {
            scrollView.contentOffset = contentOffset;
            [self performSelector:@selector(handleDrag) withObject:nil afterDelay:0.001];
        }
    }
    
    // check what is below current point, if we allow dropping it here
    NSObject* target = [self targetViewAtPoint: point];
    [self setCurrentTarget:target];
    
    [UIView performWithoutAnimation:^{
        draggingView.center = point;
    }];
    
    // fade out dragged cell when not hovering above valid target
    [UIView animateWithDuration:.1 animations:^{
        CGFloat alpha = target == nil ? 0.75 : 1.0;
        draggingView.alpha = alpha;
    }];
}

-(void)longPress:(UILongPressGestureRecognizer*)press {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleDrag) object:nil];

    UIGestureRecognizerState state = press.state;
    CGPoint point = [press locationInView: view.window];

    if(state == UIGestureRecognizerStateBegan) {
        [self startDraggingAtPoint:point];
    }
    
    // do no more if we are not part of drag
    if(!self.dragInProgress) return;
    
    // update state changes
    if(state == UIGestureRecognizerStateChanged) {
        
        lastPoint = point;
        [self handleDrag];
        
    } else if(state == UIGestureRecognizerStateEnded) {
        
        [self endDraggingPoint: point cancel:NO];

    } else if(state == UIGestureRecognizerStateCancelled ||
              state == UIGestureRecognizerStateFailed) {
        
        // abort everything
        [self endDraggingPoint: point cancel:YES];
   
    }
}

@end

@implementation UITableViewCell (AB_DragableTable)

static char associationObject;

-(void)registerForDragging {
    // do nothing when already registered
    if(objc_getAssociatedObject(self, &associationObject) != nil) return;

    AB_Dragable* dragable = [[AB_Dragable alloc] initWithCell: self];
    objc_setAssociatedObject (self, &associationObject, dragable, OBJC_ASSOCIATION_RETAIN);
}

@end
