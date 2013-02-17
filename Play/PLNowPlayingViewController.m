//
//  ViewController.m
//  Play
//
//  Created by Nathan Borror on 12/30/12.
//  Copyright (c) 2012 Nathan Borror. All rights reserved.
//

#import "PLNowPlayingViewController.h"
#import "SonosController.h"
#import "PLSong.h"
#import "SonosResponse.h"

static const CGFloat kProgressPadding = 50.0;
static const CGFloat kControlBarPadding = 5.0;
static const CGFloat kControlBarPreviousNextPadding = 40.0;
static const CGFloat kControlBarHeight = 118.0;
static const CGFloat kControlBarLandscapeHeight = 83.0;
static const CGFloat kControlBarButtonWidth = 75.0;
static const CGFloat kControlBarButtonHeight = 75.0;
static const CGFloat kControlBarButtonPadding = 20.0;

@interface PLNowPlayingViewController ()
{
  SonosController *sonos;

  UIImageView *controlBar;
  UISlider *volumeSlider;
  UIButton *playPauseButton;
  UIButton *stopButton;
  UIButton *nextButton;
  UIButton *previousButton;
  UIButton *speakersButton;
  UIImageView *album;

  UIView *trackInfo;
  UILabel *title;
  UILabel *timeTotal;
  UILabel *timeElapsed;
  UISlider *progress;

  UITableView *songList;
  UIView *tableHeader;
  NSArray *songListData;
}
@end

@implementation PLNowPlayingViewController

- (id)init
{
  self = [super init];
  if (self) {
    [self.view setBackgroundColor:[UIColor colorWithRed:.2 green:.2 blue:.2 alpha:1]];

    [self.navigationItem setTitle:@"Now Playing"];

    // Done Button
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    [self.navigationItem setRightBarButtonItem:doneButton];

    sonos = [SonosController sharedController];

    // Background
    UIImageView *background = [[UIImageView alloc] initWithFrame:CGRectMake(-100, -100, CGRectGetWidth(self.view.bounds)+200, CGRectGetHeight(self.view.bounds)+200)];
    [background setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self.view addSubview:background];

    // Header
    tableHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 390)];
    [tableHeader setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

    // Header: Album Art
    album = [[UIImageView alloc] initWithFrame:CGRectMake(30, 90, 260, 260)];
    [album setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
    [album setImage:[UIImage imageNamed:@"TempAlbum.png"]];
    [album.layer setShadowRadius:10];
    [album.layer setShadowOffset:CGSizeMake(0, 5)];
    [album.layer setShadowOpacity:.8];
    [album.layer setShadowColor:[UIColor blackColor].CGColor];
    [tableHeader addSubview:album];

    // Blurred Background
    // TODO: Perform on another thread and cache
    CIImage *inputImage = [[CIImage alloc] initWithImage:album.image];
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setDefaults];
    [blurFilter setValue:inputImage forKey:@"inputImage"];
    [blurFilter setValue:[NSNumber numberWithFloat:20.0f] forKey:@"inputRadius"];
    CIImage *outputImage = [blurFilter valueForKey:@"outputImage"];
    CIContext *context = [CIContext contextWithOptions:nil];
    [background setImage:[UIImage imageWithCGImage:[context createCGImage:outputImage fromRect:outputImage.extent]]];

    // Header: Track Title

    // Track Info
    trackInfo = [[UIView alloc] init];

    title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, CGRectGetWidth(self.view.bounds), 20)];
    [title setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [title setTextColor:[UIColor colorWithWhite:1 alpha:.9]];
    [title setBackgroundColor:[UIColor clearColor]];
    [title setTextAlignment:NSTextAlignmentCenter];
    [title setFont:[UIFont systemFontOfSize:14]];
    [title setText:@"Titanium — Nothing But The Beat"];
    [trackInfo addSubview:title];

    // Track Info: Progress Bar
    progress = [[UISlider alloc] initWithFrame:CGRectMake(kProgressPadding, 35, 320 - (kProgressPadding * 2), 20)];
    [progress setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [progress setMaximumTrackImage:[[UIImage imageNamed:@"SliderMaxValue.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 3, 3, 3) resizingMode:UIImageResizingModeStretch] forState:UIControlStateNormal];
    [progress setMinimumTrackImage:[[UIImage imageNamed:@"SliderMinValue.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 3, 3, 3) resizingMode:UIImageResizingModeStretch] forState:UIControlStateNormal];
    [progress setThumbImage:[UIImage imageNamed:@"SliderThumbSmall.png"] forState:UIControlStateNormal];
    [progress setThumbImage:[UIImage imageNamed:@"SliderThumbSmallPressed.png"] forState:UIControlStateHighlighted];
    [trackInfo addSubview:progress];

    // Track Info: Elapsed Time
    timeElapsed = [[UILabel alloc] initWithFrame:CGRectMake(5, 36, 40, 20)];
    [timeElapsed setTextColor:[UIColor colorWithWhite:1 alpha:.9]];
    [timeElapsed setBackgroundColor:[UIColor clearColor]];
    [timeElapsed setTextAlignment:NSTextAlignmentRight];
    [timeElapsed setFont:[UIFont systemFontOfSize:12]];
    [timeElapsed setText:@"02:23"];
    [trackInfo addSubview:timeElapsed];

    // Track Info: Total Time
    timeTotal = [[UILabel alloc] initWithFrame:CGRectMake(278, 36, 40, 20)];
    [timeTotal setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
    [timeTotal setTextColor:[UIColor colorWithWhite:1 alpha:.9]];
    [timeTotal setBackgroundColor:[UIColor clearColor]];
    [timeTotal setTextAlignment:NSTextAlignmentLeft];
    [timeTotal setFont:[UIFont systemFontOfSize:12]];
    [timeTotal setText:@"06:12"];
    [trackInfo addSubview:timeTotal];

    [trackInfo sizeToFit];
    [tableHeader addSubview:trackInfo];

    // TODO: Figure out why self.view.bounds isn't returning the right
    // height minus the navbar height

    // Song List
    songList = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds))];
    [songList setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [songList setBackgroundColor:[UIColor clearColor]];
    [songList setTableHeaderView:tableHeader];
    [songList setContentInset:UIEdgeInsetsMake(0, 0, 400, 0)];
    [songList setDelegate:self];
    [songList setDataSource:self];
    [songList setSeparatorColor:[UIColor colorWithWhite:1 alpha:.3]];
    [self.view addSubview:songList];

    // Control Bar
    controlBar = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"ControlBar.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(6, 6, 6, 6) resizingMode:UIImageResizingModeStretch]];
    [controlBar setFrame:CGRectMake(0, CGRectGetHeight(self.view.frame)-kControlBarHeight, CGRectGetWidth(self.view.bounds), kControlBarHeight)];
    [controlBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    [controlBar setUserInteractionEnabled:YES];

    playPauseButton = [[UIButton alloc] initWithFrame:CGRectMake((CGRectGetWidth(controlBar.bounds)/2)-kControlBarButtonWidth/2, kControlBarPadding, kControlBarButtonWidth, kControlBarButtonHeight)];
    [playPauseButton setBackgroundImage:[UIImage imageNamed:@"ControlPause.png"] forState:UIControlStateNormal];
    [playPauseButton addTarget:self action:@selector(playPause) forControlEvents:UIControlEventTouchUpInside];
    [playPauseButton setShowsTouchWhenHighlighted:YES];
    [controlBar addSubview:playPauseButton];

    nextButton = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(controlBar.bounds)-(kControlBarButtonWidth+kControlBarPreviousNextPadding), kControlBarPadding, kControlBarButtonWidth, kControlBarButtonHeight)];
    [nextButton setBackgroundImage:[UIImage imageNamed:@"ControlNext.png"] forState:UIControlStateNormal];
    [nextButton addTarget:sonos action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
    [nextButton setShowsTouchWhenHighlighted:YES];
    [controlBar addSubview:nextButton];

    previousButton = [[UIButton alloc] initWithFrame:CGRectMake(kControlBarPreviousNextPadding, kControlBarPadding, kControlBarButtonWidth, kControlBarButtonHeight)];
    [previousButton setBackgroundImage:[UIImage imageNamed:@"ControlPrevious.png"] forState:UIControlStateNormal];
    [previousButton addTarget:sonos action:@selector(previous) forControlEvents:UIControlEventTouchUpInside];
    [previousButton setShowsTouchWhenHighlighted:YES];
    [controlBar addSubview:previousButton];

    volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(kControlBarButtonPadding, 80, CGRectGetWidth(controlBar.bounds)-(kControlBarButtonPadding*2), 20)];
    [volumeSlider setMaximumValue:100];
    [volumeSlider setMinimumValue:0];
    [volumeSlider setValue:20];
    [volumeSlider setMaximumTrackImage:[[UIImage imageNamed:@"SliderMaxValue.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 3, 3, 3) resizingMode:UIImageResizingModeStretch] forState:UIControlStateNormal];
    [volumeSlider setMinimumTrackImage:[[UIImage imageNamed:@"SliderMinValue.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 3, 3, 3) resizingMode:UIImageResizingModeStretch] forState:UIControlStateNormal];
    [volumeSlider setThumbImage:[UIImage imageNamed:@"SliderThumb.png"] forState:UIControlStateNormal];
    [volumeSlider setThumbImage:[UIImage imageNamed:@"SliderThumbPressed.png"] forState:UIControlStateHighlighted];
    [volumeSlider addTarget:self action:@selector(volume:) forControlEvents:UIControlEventValueChanged];
    [controlBar addSubview:volumeSlider];
    
    [self.view addSubview:controlBar];


//    [sonos trackInfoWithCompletion:^(SonosResponse *response, NSError *error) {
//      // TODO: Update labels and song position
//      NSLog(@"RESPONSE: %@", response.action);
//      NSLog(@"TEST: %@", error.localizedDescription);
//    }];
//    [sonos browseWithCompletion:^(SonosResponse *response, NSError *error) {
//      //
//    }];
  }
  return self;
}

- (id)initWithSong:(PLSong *)song
{
  self = [self init];
  if (self) {
    [self setCurrentSong:song];
  }
  return self;
}

- (id)initWithLineIn:(NSString *)uid
{
  self = [self init];
  if (self) {
    [sonos lineIn:uid];
    [album setImage:[UIImage imageNamed:@"LineIn.png"]];
    [title setText:[NSString stringWithFormat:@"%@ - Line In", [[NSUserDefaults standardUserDefaults] objectForKey:@"current_input_name"]]];
    [timeElapsed setText:@"00:00"];
    [timeTotal setText:@"00:00"];
  }
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  [controlBar setFrame:CGRectOffset(controlBar.bounds, 0, CGRectGetHeight(self.view.frame)-kControlBarHeight)];
}

- (void)playPause
{
  if (sonos.isPlaying) {
    [sonos pause];
    [playPauseButton setBackgroundImage:[UIImage imageNamed:@"ControlPlay.png"] forState:UIControlStateNormal];
  } else {
    [sonos play:nil];
    [playPauseButton setBackgroundImage:[UIImage imageNamed:@"ControlPause.png"] forState:UIControlStateNormal];
  }
}

- (void)volume:(UISlider *)sender
{
  [sonos volume:(int)[sender value]];
}

- (void)done
{
  [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)setCurrentSong:(PLSong *)song
{
  [title setText:[NSString stringWithFormat:@"%@ - %@", song.title, song.album]];
  [album setImage:song.albumArt];
  [timeTotal setText:song.duration];
  [sonos play:song.uri];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
    // Portrait
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [self.navigationController setNavigationBarHidden:NO animated:YES];

    [controlBar setFrame:CGRectMake(0, CGRectGetHeight(self.view.frame)-kControlBarHeight, CGRectGetWidth(self.view.bounds), kControlBarHeight)];
    [volumeSlider setFrame:CGRectMake(kControlBarButtonPadding, 80, CGRectGetWidth(controlBar.bounds)-(kControlBarButtonPadding*2), 20)];

    [album setFrame:CGRectMake(30, 90, 260, 260)];

    [trackInfo setFrame:CGRectOffset(trackInfo.bounds, 0, 0)];
  } else {
    // Landscape
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    [self.navigationController setNavigationBarHidden:YES animated:YES];

    [controlBar setFrame:CGRectMake(0, CGRectGetHeight(self.view.frame)-kControlBarLandscapeHeight, CGRectGetWidth(self.view.bounds), kControlBarLandscapeHeight)];
    [volumeSlider setFrame:CGRectMake(kControlBarButtonPadding+280, 34, 250, 20)];

    [album setFrame:CGRectMake(15, 15, 209, 209)];

    [trackInfo setFrame:CGRectOffset(trackInfo.bounds, CGRectGetWidth(album.bounds)+20, 20)];
  }
}

#pragma mark - UITableViewController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [songListData count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  PLSong *song = [songListData objectAtIndex:indexPath.row];
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TableViewCell"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TableViewCell"];
  }
  [cell.textLabel setFont:[UIFont systemFontOfSize:16]];
  [cell.textLabel setTextColor:[UIColor whiteColor]];
  [cell.textLabel setText:song.title];
  
  if (indexPath.row % 2) {
    [cell.contentView setBackgroundColor:[UIColor colorWithRed:.15 green:.15 blue:.15 alpha:1]];
  } else {
    [cell.contentView setBackgroundColor:[UIColor clearColor]];
  }
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  PLSong *song = [songListData objectAtIndex:indexPath.row];
  [self setCurrentSong:song];
}

@end