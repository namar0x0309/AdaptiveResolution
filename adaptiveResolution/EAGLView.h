//
//  AppDelegate.h
//  adaptiveResolution
//
//  Created by Nassim Amar on 9/18/11.
//  Copyright (c) 2011. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import <sys/time.h>

#import "musingsFont/font.h"

#import <GLKit/GLKMath.h>

#define MSAA_LOWER_BOUND 1
#define MSAA_UPPER_BOUND 2
#define SCL_LOWER_BOUND 0.5f
#define SCL_UPPER_BOUND 1.2f
#define SCL_STEP_SIZE 0.1f
#define FPS_DELTA_LO_THRESHHOLD 11       // microseconds
#define FPS_DELTA_UP_THRESHHOLD 9       // microseconds

#define SAMPLE_CNT 10
#define SAMPLE_TIME_THRESHHOLD 1000
#define TRI_BUILD_STEP 10

@class EAGLView;

@interface EAGLView : UIView
{
@private
    //Framebuffer resolutions
    GLint backingWidth;
    GLint backingHeight;
    
    //Optimization
    float drawLatencyAvg,drawLatencyAvgPrev; 
    CGFloat resScale; 
    GLint sampleSize; 
    bool isOptimizationUpNeeded,isOptimizationLoNeeded;
    bool isMSAAOn,enableMSAA; 
    unsigned int prev_optimize_time, curr_time, sampleCnt, drawLatency, prev_time; 
    
    unsigned int itime;         // Used by elapsed time function
    
    //Sample - Multisampling | All resolved in resolve framebuffer
    GLuint sampleRB,sampleFB,sampleDB;	    
    GLuint resolveFB,resolveRB;
    
    //GLExtension Discard Compatibility
    bool isCapableOS4; 
    
	EAGLContext			*m_context;
	UIWindow*			m_window;
	NSTimer*			m_renderTimer;	
    
    //ASSETS
    GLuint				m_ui32Vbo;	
    Font                *m_font; 
	uint				cnt_tri; 
	GLKVector3			*triangles;
    unsigned int        cntTriToBuild;
    bool isAdding; 
}

+ (Class) layerClass;
- (void) applicationDidFinishLaunching:(UIApplication*)application;
- (void) RenderScene;
- (void) dealloc;
@end
