/*****************************************************************************
 * test: Controller.m
 *****************************************************************************
 * Copyright (C) 2007-2013 Pierre d'Herbemont and VideoLAN
 *
 * Authors: Pierre d'Herbemont
 *          Felix Paul Kühne
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "Controller.h"

@implementation Controller

- (void)awakeFromNib
{
    [NSApp setDelegate:self];

    // Allocate a VLCVideoView instance and tell it what area to occupy.
  CGSize size = [videoHolderView frame].size;
  NSRect rect1 = NSMakeRect(0, 0, size.width / 2, size.height);
  NSRect rect2 = NSMakeRect(size.width / 2, 0, size.width / 2, size.height);
  
  videoView1 = [[VLCVideoView alloc] initWithFrame:rect1];
  videoView2 = [[VLCVideoView alloc] initWithFrame:rect2];
  [videoHolderView addSubview:videoView1];
  [videoHolderView addSubview:videoView2];
  [videoView1 setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
  videoView1.fillScreen = YES;
  [videoView2 setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
  videoView2.fillScreen = YES;

    [VLCLibrary sharedLibrary];

    playlist = [[VLCMediaList alloc] init];
    [playlist addObserver:self forKeyPath:@"media" options:NSKeyValueObservingOptionNew context:nil];
  
  player1 = [[VLCMediaPlayer alloc] initWithVideoView:videoView1];
  player2 = [[VLCMediaPlayer alloc] initWithVideoView:videoView2];
  player1.delegate = self;
  player2.delegate = self;
    mediaIndex = -1;

    [playlistOutline registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
    [playlistOutline setDoubleAction:@selector(changeAndPlay:)];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [playlist removeObserver:self forKeyPath:@"media"];
  
  [player1 pause];
  [player1 setMedia:nil];
  [player1 release];
  [player2 pause];
  [player2 setMedia:nil];
  [player2 release];
  [playlist release];
  [videoView1 release];
  [videoView2 release];
}

- (void)changeAndPlay:(id)sender
{
    if ([playlistOutline selectedRow] != mediaIndex) {
        [self setMediaIndex:[playlistOutline selectedRow]];
      if (![player1 isPlaying])
        [player1 play];
      if (![player2 isPlaying])
        [player2 play];
    }
}

- (void)setMediaIndex:(int)value
{
    if ([playlist count] <= 0)
        return;

    if (value < 0)
        value = 0;
    if (value > [playlist count] - 1)
        value = [playlist count] - 1;

  mediaIndex = value;
  [player1 setMedia:[playlist mediaAtIndex:mediaIndex]];
  [player2 setMedia:[playlist mediaAtIndex:mediaIndex]];
}

- (void)play:(id)sender
{
    [self setMediaIndex:mediaIndex+1];
    if (![player1 isPlaying] && [playlist count] > 0) {
        NSLog(@"%@ length = %@", [playlist mediaAtIndex:mediaIndex], [[playlist mediaAtIndex:mediaIndex] lengthWaitUntilDate:[NSDate dateWithTimeIntervalSinceNow:60]]);
        [player1 play];
      [player2 play];
    }
}

- (void)pause:(id)sender
{
  NSLog(@"Sending pause message to media player...");
  [player1 pause];
  [player2 pause];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    if (player1.media) {
        NSArray *spuTracks = [player1 videoSubTitlesNames];
        NSArray *spuTrackIndexes = [player1 videoSubTitlesIndexes];

        NSUInteger count = [spuTracks count];
        [spuPopup removeAllItems];
        if (count <= 1)
            return;

        for (NSUInteger x = 0; x < count; x++) {
            [spuPopup addItemWithTitle:spuTracks[x]];
            [[spuPopup lastItem] setTag:spuTrackIndexes[x]];
        }
    }
}

- (void)setSPU:(id)sender
{
    if (player1.media)
        player1.currentVideoSubTitleIndex = [[spuPopup selectedItem] tag];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"media"] && object == playlist)
        [playlistOutline reloadData];
}

// NSTableView Implementation
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [playlist count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(int)row
{
    NSString *title = [(VLCMedia *)[playlist mediaAtIndex:row].metaDictionary valueForKey:VLCMetaInformationTitle];

    return title ? title : [playlist mediaAtIndex:row].url.lastPathComponent;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    return NSDragOperationEvery; /* This is for now */
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSArray *droppedItems = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];

    for (int i = 0; i < [droppedItems count]; i++) {
        NSString * filename = [droppedItems objectAtIndex:i];
        VLCMedia * media = [VLCMedia mediaWithPath:filename];
        [playlist addMedia:media];
    }
    return YES;
}

@end
