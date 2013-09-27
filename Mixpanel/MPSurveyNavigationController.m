#import <QuartzCore/QuartzCore.h>

#import "MPSurvey.h"
#import "MPSurveyNavigationController.h"
#import "MPSurveyQuestion.h"
#import "MPSurveyQuestionViewController.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"

@interface MPSurveyNavigationController () <MPSurveyQuestionViewControllerDelegate>

@property(nonatomic,retain) IBOutlet UIImageView *view;
@property(nonatomic,retain) IBOutlet UIView *containerView;
@property(nonatomic,retain) IBOutlet UILabel *pageNumberLabel;
@property(nonatomic,retain) IBOutlet UIButton *nextButton;
@property(nonatomic,retain) IBOutlet UIButton *previousButton;
@property(nonatomic,retain) IBOutlet UIImageView *logo;
@property(nonatomic,retain) IBOutlet UIButton *exitButton;
@property(nonatomic,retain) IBOutlet UIView *header;
@property(nonatomic,retain) IBOutlet UIView *footer;
@property(nonatomic,retain) NSMutableArray *questionControllers;
@property(nonatomic) UIViewController *currentQuestionController;
@property(nonatomic) BOOL answeredOneQuestion;

@end

@implementation MPSurveyNavigationController

- (void)dealloc
{
    self.survey = nil;
    self.backgroundImage = nil;
    self.questionControllers = nil;
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.image = [_backgroundImage mp_applyDarkEffect];
    self.questionControllers = [NSMutableArray array];
    for (NSUInteger i = 0; i < _survey.questions.count; i++) {
        [_questionControllers addObject:[NSNull null]];
    }
    [self loadQuestion:0];
    [self loadQuestion:1];
    MPSurveyQuestionViewController *firstQuestionController = _questionControllers[0];
    [self addChildViewController:firstQuestionController];
    [_containerView addSubview:firstQuestionController.view];
    [self constrainQuestionView:firstQuestionController.view];
    [firstQuestionController didMoveToParentViewController:self];
    _currentQuestionController = firstQuestionController;
    [firstQuestionController.view setNeedsUpdateConstraints];
    [self updatePageNumber:0];
    [self updateButtons:0];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 0.0;
                         _header.center = CGPointMake(_header.center.x, _header.center.y - _header.bounds.size.height * 5);
                         _containerView.center = CGPointMake(_containerView.center.x, _containerView.center.y + self.view.bounds.size.height);
                         _footer.center = CGPointMake(_footer.center.x, _footer.center.y + _footer.bounds.size.height * 5);
                     }
                     completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _header.center = CGPointMake(_header.center.x, _header.center.y - _header.bounds.size.height * 5);
    _containerView.center = CGPointMake(_containerView.center.x, _containerView.center.y + self.view.bounds.size.height);
    _footer.center = CGPointMake(_footer.center.x, _footer.center.y + _footer.bounds.size.height * 5);
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 1.0;
                         [self.view layoutIfNeeded];
                     }
                     completion:nil];
}

- (void)updatePageNumber:(NSUInteger)index
{
    _pageNumberLabel.text = [NSString stringWithFormat:@"%d of %d", index + 1, _survey.questions.count];
}

- (void)updateButtons:(NSUInteger)index
{
    _previousButton.enabled = index > 0;
    _nextButton.enabled = index < ([_survey.questions count] - 1);
}

- (void)loadQuestion:(NSUInteger)index
{
    if (index < _survey.questions.count) {
        MPSurveyQuestionViewController *controller = _questionControllers[index];
        // replace the placeholder if necessary
        if ((NSNull *)controller == [NSNull null]) {
            MPSurveyQuestion *question = _survey.questions[index];
            NSString *storyboardIdentifier = [NSString stringWithFormat:@"%@ViewController", NSStringFromClass([question class])];
            controller = [self.storyboard instantiateViewControllerWithIdentifier:storyboardIdentifier];
            if (!controller) {
                NSLog(@"no view controller for storyboard identifier: %@", storyboardIdentifier);
                return;
            }
            controller.delegate = self;
            controller.question = question;
            controller.highlightColor = [[_backgroundImage mp_averageColor] colorWithAlphaComponent:0.6];
            controller.view.translatesAutoresizingMaskIntoConstraints = NO; // we contrain with auto layout in constrainQuestionView:
            _questionControllers[index] = controller;
        }
    }
}

- (void)constrainQuestionView:(UIView *)view
{
    NSDictionary *views = NSDictionaryOfVariableBindings(view);
    [_containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];
    [_containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];
}

- (void)showQuestionAtIndex:(NSUInteger)index animatingForward:(BOOL)forward
{
    if (index < [_survey.questions count]) {

        UIViewController *fromController = _currentQuestionController;

        [self loadQuestion:index];
        UIViewController *toController = _questionControllers[index];

        [fromController willMoveToParentViewController:nil];
        [self addChildViewController:toController];

        // reset after being faded out last time
        toController.view.alpha = 1.0;

        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

        NSTimeInterval duration = 0.25;
        [self transitionFromViewController:fromController
                          toViewController:toController
                                  duration:duration
                                   options:UIViewAnimationOptionCurveEaseIn
                                animations:^{

                                    // position to view with auto layout
                                    [self constrainQuestionView:toController.view];

                                    NSMutableArray *anims;
                                    CABasicAnimation *basicAnim;
                                    CAKeyframeAnimation *keyFrameAnim;
                                    CAAnimationGroup *group;
                                    NSArray *keyTimes;

                                    CGFloat slideDistance = _containerView.bounds.size.width * 1.3;
                                    CGFloat dropDistance = _containerView.bounds.size.height / 4.0;

                                    if (forward) {

                                        // from view
                                        anims = [NSMutableArray array];
                                        // slides left
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                                        basicAnim.byValue = @(-slideDistance);
                                        [anims addObject:basicAnim];
                                        // after a moment, rotates counterclockwise and shrinks a bit as it moves offscreen
                                        keyTimes = @[@0.0, @0.4, @1.0];
                                        keyFrameAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
                                        keyFrameAnim.keyTimes = keyTimes;
                                        keyFrameAnim.values = @[@0.0, @0.0, @(-M_PI_4)];
                                        [anims addObject:keyFrameAnim];
                                        keyFrameAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
                                        keyFrameAnim.keyTimes = keyTimes;
                                        keyFrameAnim.values = @[@1.0, @1.0, @0.8];
                                        [anims addObject:keyFrameAnim];
                                        group = [CAAnimationGroup animation];
                                        group.animations = anims;
                                        group.duration = duration;
                                        [fromController.view.layer addAnimation:group forKey:nil];

                                        // to view
                                        anims = [NSMutableArray array];
                                        // starts offscreen, down, to the right and rotated clockwise, then snaps into place
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
                                        basicAnim.fromValue = @(dropDistance);
                                        basicAnim.byValue = @(-dropDistance);
                                        [anims addObject:basicAnim];
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                                        basicAnim.fromValue = @(slideDistance);
                                        basicAnim.byValue = @(-slideDistance);
                                        [anims addObject:basicAnim];
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
                                        basicAnim.fromValue = @(M_PI_4);
                                        basicAnim.byValue = @(-M_PI_4);
                                        [anims addObject:basicAnim];
                                        group = [CAAnimationGroup animation];
                                        group.animations = anims;
                                        group.duration = duration;
                                        [toController.view.layer addAnimation:group forKey:nil];

                                    } else {

                                        // from view
                                        anims = [NSMutableArray array];
                                        // slides right and spins and drops offscreen
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
                                        basicAnim.byValue = @(dropDistance);
                                        [anims addObject:basicAnim];
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                                        basicAnim.byValue = @(slideDistance);
                                        [anims addObject:basicAnim];
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
                                        basicAnim.byValue = @(M_PI_4);
                                        [anims addObject:basicAnim];
                                        group = [CAAnimationGroup animation];
                                        group.animations = anims;
                                        group.duration = duration;
                                        [fromController.view.layer addAnimation:group forKey:nil];

                                        // to view
                                        anims = [NSMutableArray array];
                                        // slides right into place
                                        basicAnim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                                        basicAnim.fromValue = @(-slideDistance);
                                        basicAnim.byValue = @(slideDistance);
                                        [anims addObject:basicAnim];
                                        // grows and rotates clockwise at the beginning
                                        keyTimes = @[@0.0, @0.6, @1.0];
                                        keyFrameAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
                                        keyFrameAnim.keyTimes = keyTimes;
                                        keyFrameAnim.values = @[@(-M_PI_4), @0.0, @0.0];
                                        [anims addObject:keyFrameAnim];
                                        keyFrameAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
                                        keyFrameAnim.keyTimes = keyTimes;
                                        keyFrameAnim.values = @[@0.8, @1.0, @1.0];
                                        [anims addObject:keyFrameAnim];
                                        group = [CAAnimationGroup animation];
                                        group.animations = anims;
                                        group.duration = duration;
                                        [toController.view.layer addAnimation:group forKey:nil];
                                    }

                                    // hack to hide animation flashing fromController.view at the end
                                    fromController.view.alpha = 0.0;

                               }
                                completion:^(BOOL finished){
                                    [toController didMoveToParentViewController:self];
                                    [fromController removeFromParentViewController];
                                    _currentQuestionController = toController;
                                    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                                }];
        [self updatePageNumber:index];
        [self updateButtons:index];
        [self loadQuestion:index - 1];
        [self loadQuestion:index + 1];
    } else {
        NSLog(@"attempt to navigate to invalid question index");
    }
}

- (NSUInteger)currentIndex
{
    return [_questionControllers indexOfObject:_currentQuestionController];
}

- (IBAction)showNextQuestion
{
    NSUInteger currentIndex = [self currentIndex];
    if (currentIndex < (_survey.questions.count - 1)) {
        [self showQuestionAtIndex:currentIndex + 1 animatingForward:YES];
    }
}

- (IBAction)showPreviousQuestion
{
    NSUInteger currentIndex = [self currentIndex];
    if (currentIndex > 0) {
        [self showQuestionAtIndex:currentIndex - 1 animatingForward:NO];
    }
}

- (IBAction)dismiss
{
    [_delegate surveyControllerWasDismissed:self];
}

- (void)questionController:(MPSurveyQuestionViewController *)controller didReceiveAnswerProperties:(NSDictionary *)properties
{
    NSMutableDictionary *answer = [NSMutableDictionary dictionaryWithDictionary:properties];
    answer[@"$collection_id"] = @(_survey.collectionID);
    answer[@"$question_id"] = @(controller.question.ID);
    answer[@"$question_type"] = controller.question.type;
    answer[@"$survey_id"] = @(_survey.ID);
    answer[@"$time"] = [NSDate date];
    [_delegate surveyController:self didReceiveAnswer:answer];
    if ([self currentIndex] < ([_survey.questions count] - 1)) {
        [self showNextQuestion];
    } else {
        [self dismiss];
    }
}

@end
