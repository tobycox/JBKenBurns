//
//  KenBurnsView.m
//  KenBurns
//
//  Created by Javier Berlana on 9/23/11.
//  Copyright (c) 2011, Javier Berlana
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this 
//  software and associated documentation files (the "Software"), to deal in the Software 
//  without restriction, including without limitation the rights to use, copy, modify, merge, 
//  publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
//  to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies 
//  or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
//  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
//  IN THE SOFTWARE.
//

#import "JBKenBurnsView.h"
#include <stdlib.h>

#define enlargeRatio 1.1
#define imageBufer 3

enum JBSourceMode {
    JBSourceModeImages,
//    JBSourceModeURLs,
    JBSourceModePaths
};

// Private interface
@interface JBKenBurnsView (){
    NSMutableArray *_imagesArray;
    CGFloat _showImageDuration;
    BOOL _shouldLoop;
    BOOL _isLandscape;

    NSTimer *_nextImageTimer;
    enum JBSourceMode _sourceMode;
}

@end


@implementation JBKenBurnsView

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setup];
}

- (void)setup
{
    self.backgroundColor = [UIColor clearColor];
    self.layer.masksToBounds = YES;
}

- (void) animateWithImagePaths:(NSArray *)imagePaths transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape
{
    _sourceMode = JBSourceModePaths;
    [self _startAnimationsWithData:imagePaths transitionDuration:duration loop:shouldLoop isLandscape:isLandscape];
}

- (void) animateWithImages:(NSArray *)images transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape {
    _sourceMode = JBSourceModeImages;
    [self _startAnimationsWithData:images transitionDuration:duration loop:shouldLoop isLandscape:isLandscape];
}

- (void)stopAnimation {
    if (_nextImageTimer && [_nextImageTimer isValid]) {
        [_nextImageTimer invalidate];
        _nextImageTimer = nil;
    }
}

- (void)_startAnimationsWithData:(NSArray *)data transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape
{
    _imagesArray        = [data mutableCopy];
    _showImageDuration  = duration;
    _shouldLoop         = shouldLoop;
    _isLandscape        = isLandscape;

    // start at 0
    _currentImageIndex = -1;

    _nextImageTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(nextImage) userInfo:nil repeats:YES];
    [_nextImageTimer fire];
}

- (UIImage *)currentImage
{
    UIImage *image = nil;
    switch (_sourceMode) {
        case JBSourceModeImages:
            image = _imagesArray[MAX(self.currentImageIndex, 0)];
            break;
            
        case JBSourceModePaths:
            image = [UIImage imageWithContentsOfFile:_imagesArray[MAX(self.currentImageIndex, 0)]];
            break;
    }
    
    return image;
}

- (NSArray *)images
{
    return _imagesArray;
}

- (void)nextImage {
    _currentImageIndex++;

    UIImage *image = self.currentImage;
    UIImageView *imageView = nil;
    
    float scaleFactor = 1.4;
    float width = self.bounds.size.width;
    float height = self.bounds.size.height;
    float marginX = ((width * scaleFactor) - width) / 2;
    float marginY = ((height * scaleFactor) - height) / 2;
    float originX = -1;
    float originY = -1;
    
    imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    imageView.backgroundColor = [UIColor blackColor];
    
    float rotation = (arc4random() % 9) / 100;
    
    switch (arc4random() % 4) {
        case 0: // Top left
            originX = 0;
            originY = 0;
            break;
            
        case 1: // Top right
            originX = -marginX;
            originY = 0;
            break;
            
        case 2: // Bottom left
            originX = 0;
            originY = -marginY;
            break;
            
        case 3:
            originX = -marginX;
            originY = -marginY;
            break;
            
        default:
            [NSException raise:@"Unknown random number found in JBKenBurnsView _animate" format:@""];
            break;
    }
    CALayer *picLayer    = [CALayer layer];
    picLayer.contents    = (id)image.CGImage;
    picLayer.anchorPoint = CGPointMake(0, 0);
    picLayer.bounds      = CGRectMake(0, 0, width, height);
    picLayer.position    = CGPointMake(0, 0);
    
    [imageView.layer addSublayer:picLayer];
    
    CATransition *animation = [CATransition animation];
    [animation setDuration:1];
    [animation setType:kCATransitionFade];
    [[self layer] addAnimation:animation forKey:nil];
    
    // Remove the previous view
    if ([[self subviews] count] > 0){
        UIView *oldImageView = [[self subviews] objectAtIndex:0];
        [oldImageView removeFromSuperview];
        oldImageView = nil;
    }
    
    [self addSubview:imageView];
    
    // Generates the animation
    [UIView animateWithDuration:_showImageDuration + 2 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
        CGAffineTransform rotate    = CGAffineTransformMakeRotation(rotation);
        CGAffineTransform move = CGAffineTransformTranslate(rotate, originX, originY);
        CGAffineTransform zoomIn    = CGAffineTransformScale(move, scaleFactor, scaleFactor);
        imageView.transform = zoomIn;
    } completion:^(BOOL finished) {
        
    }];
    
    
    [UIView commitAnimations];
    
    [self _notifyDelegate];

    if (_currentImageIndex == _imagesArray.count - 1) {
        if (_shouldLoop) {
            _currentImageIndex = -1;
        }else {
            [_nextImageTimer invalidate];
        }
    }
}

- (void) _notifyDelegate
{
    if (_delegate) {
        if([_delegate respondsToSelector:@selector(didShowImageAtIndex:)])
        {
            [_delegate didShowImageAtIndex:_currentImageIndex];
        }      
        
        if (_currentImageIndex == ([_imagesArray count] - 1) && !_shouldLoop && [_delegate respondsToSelector:@selector(didFinishAllAnimations)]) {
            [_delegate didFinishAllAnimations];
        } 
    }
    
}

@end
