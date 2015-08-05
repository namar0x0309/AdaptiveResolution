//
//  AppDelegate.mm
//  adaptiveResolution
//
//  Created by Nassim Amar on 9/18/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "EAGLView.h"


// Index to bind the attributes to vertex shaders
#define VERTEX_ARRAY	0
#define KFPS			120.0


// A class extension to declare private methods
@interface EAGLView (PrivateMethods)

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, retain) NSTimer *animationTimer;

- (BOOL) createFramebuffers;
- (void) destroyFramebuffers;

- (void) createSamplebuffer; 
- (void) destroySamplebuffer;

- (void)setInitResScale;
- (void)optimizeLoResScale;
- (void)optimizeUpResScale;

- (void)layoutSubviews;
- (unsigned int) ElapsedTime; 

- (void) setPerspective:(float)_fovy: (float)_aspect:(float) _zNear:(float) _zFar;
- (void) addTriangle; 
- (void) removeTriangle; 

@end

@implementation EAGLView

+ (Class) layerClass
{
	return [CAEAGLLayer class];
}


- (void) applicationDidFinishLaunching:(UIApplication*)application
{
    UIApplication *app = [UIApplication sharedApplication];

    /*
     Step 0 - Setup Window.
     */
    CGRect rect = [[UIScreen mainScreen] bounds];
	m_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	if(!(self = [super initWithFrame:rect])) 
	{
		[self release];
		return;
	}
    
    /*
     Step 0.1 - Setup viewController.
     */
    UIViewController *viewController = [[UIViewController alloc] init];
    [m_window setRootViewController: viewController];
    [viewController setView: self];
    
	/*
     Step 1 -Initialise EAGL.
     */
	CAEAGLLayer* eaglLayer = (CAEAGLLayer*)[self layer];	
	[eaglLayer setDrawableProperties: [	NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:NO], 
									   kEAGLDrawablePropertyRetainedBacking, 
									   kEAGLColorFormatRGBA8, 
									   kEAGLDrawablePropertyColorFormat, 
									   nil]];
	
	m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    
    
	if((!m_context) || (![EAGLContext setCurrentContext:m_context])) 
	{
		[self release];
		return;
	}
    
    drawLatencyAvgPrev = 0.0f;
    drawLatency = [self ElapsedTime]; 
    drawLatencyAvg = 0; 
    prev_optimize_time = [self ElapsedTime];
    enableMSAA = true; 
    isMSAAOn = true; 
    isCapableOS4 = true; 
    
    [self setInitResScale]; 
    [self createFramebuffers];

	[m_window addSubview: self];
    
    // Drawing Setup
    isAdding = true; 
    glClearColor(0.2f, 0.2f, 0.2f, 1.0f); // clear blue
    
    // We're going to draw a triangle to the screen so create a vertex buffer object for our triangle
    // Interleaved vertex data
    float afVertices[] = { -0.5f , -0.5f, 0.0f,
							0.5f,  -0.5f, 0.0f,
							0.0f, 0.5f,	  0.0f };
    
    glGenBuffers(1, &m_ui32Vbo);
    glBindBuffer(GL_ARRAY_BUFFER, m_ui32Vbo);
    unsigned int uiSize = 3 * (sizeof(GLfloat) * 3); // Calc afVertices size (3 vertices * stride (7 verttypes per vertex (3 pos + 4 colour)))
    glBufferData(GL_ARRAY_BUFFER, uiSize, afVertices, GL_STATIC_DRAW);
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	m_renderTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / KFPS) target:self selector:@selector(RenderScene) userInfo:nil repeats:YES];	
    
    m_font = new Font("Helvetica"); 
	
	triangles = nil;
	
    cntTriToBuild = TRI_BUILD_STEP;
    
    m_window.backgroundColor = [UIColor grayColor];
    [m_window makeKeyAndVisible];
}

- (void) dealloc
{
	[m_window release];
	
	EAGLContext *oldContext = [EAGLContext currentContext];
	
	free(triangles);
	
	if (oldContext != m_context)
		[EAGLContext setCurrentContext:m_context];
	
    
    [self destroyFramebuffers]; 
	
	if (oldContext != m_context)
		[EAGLContext setCurrentContext:oldContext];
	
	[m_context release];
	m_context = nil;
	
    delete m_font; 
    
	[super dealloc];
}


- (void) addTriangle {
	++cnt_tri; 
	triangles = (GLKVector3*)realloc(triangles, sizeof(GLKVector3) * cnt_tri );
	triangles[cnt_tri - 1].x = (float)(rand()%5 - 2);
	triangles[cnt_tri - 1].y = (float)(rand()%5 - 2);
	triangles[cnt_tri - 1].z = (float)(rand()%100);
}

- (void) removeTriangle {
    if( !cnt_tri ) return; 
	--cnt_tri; 
	triangles = (GLKVector3*)realloc(triangles, sizeof(GLKVector3) * cnt_tri );
}

- (void)layoutSubviews {
	[EAGLContext setCurrentContext:m_context];
	[self destroyFramebuffers];
	[self createFramebuffers];
	[self RenderScene];
}

- (void) RenderScene
{	
    [EAGLContext setCurrentContext:m_context];

    if(isOptimizationLoNeeded || isOptimizationUpNeeded){
        if(isOptimizationLoNeeded)
            [self optimizeLoResScale];
        else
            [self optimizeUpResScale];
        if(!enableMSAA) isMSAAOn = false; 
        [[[m_window subviews] objectAtIndex:0] setNeedsLayout]; 
    }
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, sampleFB);
    glViewport(0, 0, backingWidth, backingHeight);
        
	glClear( GL_COLOR_BUFFER_BIT );

    [self setPerspective:78.0f: ( (float)backingWidth / (float)backingHeight ) : 0.1f: 1000.0f];

	// Rendering 
    glLoadIdentity(); 
    glTranslatef(0.0f, 0.0f, -150.0f);
	glRotatef(cnt_tri, 1.0f, 0.5f, 0.0f);

    // 3d Rendering
	glBindBuffer(GL_ARRAY_BUFFER, m_ui32Vbo);
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, sizeof(float) * 7, 0);	
	
    // Add Remove triangles.
	if( isAdding ) {
        if(cnt_tri < cntTriToBuild)
            [self addTriangle];
        else
            isAdding = false;
    } else {
        if(cnt_tri > 0)
            [self removeTriangle];
        else {
            isAdding = true;
            cntTriToBuild = TRI_BUILD_STEP * rand();
        }
    }
    
    // Draw Triangles
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); 
	for( int i = 0; i < cnt_tri; ++i ) {
		glPushMatrix(); {
			glScalef( 10.0f, 10.0f, 1.0f );
			glTranslatef( triangles[i].x, triangles[i].y, triangles[i].z );
			//glRotatef( i , 0.0f, 1.0f, 0.0f);
			glColor4ub(rand()%255, rand()%255, rand()%255, rand()%100 + 50);
			glDrawArrays( GL_TRIANGLES, 0, 3 );
		} glPopMatrix(); 
	}
	
	
	// Reset States
	glDisable(GL_BLEND); 
	glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY); 
    
    // 2d Drawing - Text Info and Stats.
    glMatrixMode(GL_PROJECTION); 
    glLoadIdentity(); 
    glOrthof(0.0f, backingWidth, backingHeight, 0.0f, -1.0f, 1.0f);
    
    glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix(); 
    {
        glLoadIdentity(); 
        
        float scaleText = .5f; 
        glScalef(((CAEAGLLayer *)self.layer).contentsScale * scaleText,
                 ((CAEAGLLayer *)self.layer).contentsScale * scaleText, 1) ;
        
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
        
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glEnable(GL_TEXTURE_2D);
        
        char str[256]; 
        sprintf( str, "MSAA Sample Size:%d", sampleSize );
        m_font->print(str, 10, 60, 0);
		sprintf( str, "Scale: %g", resScale );
		m_font->print(str, 10, 100, 0);
		sprintf( str, "Triangle Count: %d", cnt_tri );
		m_font->print(str, 10, 140, 0);
        sprintf( str, "Latency: %d", drawLatency );
		m_font->print(str, 10, 180, 0);
        sprintf( str, "Avg. Latency: %g", drawLatencyAvgPrev );
        m_font->print(str, 10, 220, 0); 
    }
    glPopMatrix(); 
    
    glDisable(GL_BLEND); 
    glDisable(GL_TEXTURE_2D); 
    // Rendering End
    
    // Adaptive Resolution:
    // Check for potential optimizations
    prev_time = curr_time; 
    curr_time = [self ElapsedTime];
    drawLatency = curr_time - prev_time; 

    if( curr_time - prev_optimize_time > SAMPLE_TIME_THRESHHOLD){
        
        if( sampleCnt < SAMPLE_CNT ) {
            drawLatencyAvg += (float)drawLatency; 
            ++sampleCnt; 
        }
        // Pick scale up or down
        else {
            drawLatencyAvg /= sampleCnt; 
            if( drawLatencyAvg > FPS_DELTA_LO_THRESHHOLD ){
                if(resScale != SCL_LOWER_BOUND ||
                   sampleSize != MSAA_LOWER_BOUND)
                    isOptimizationLoNeeded = true; 
            } else if ( drawLatency < FPS_DELTA_UP_THRESHHOLD ){
                if(resScale != SCL_UPPER_BOUND||
                   sampleSize != MSAA_UPPER_BOUND)
                    isOptimizationUpNeeded = true; 
            }
            sampleCnt = 0; 
            drawLatencyAvgPrev = drawLatencyAvg; 
            drawLatencyAvg = 0.0f; 
        }
        prev_optimize_time = curr_time; 
    }
    
    if(isCapableOS4){
        const GLenum discards[]  = {GL_COLOR_ATTACHMENT0_OES,GL_DEPTH_ATTACHMENT_OES};
        glDiscardFramebufferEXT(GL_FRAMEBUFFER_OES,sampleSize,discards);
    }    
    
    if(isMSAAOn){
        glBindFramebufferOES(GL_READ_FRAMEBUFFER_APPLE, sampleFB); 
        glBindFramebufferOES(GL_DRAW_FRAMEBUFFER_APPLE, resolveFB);
        glResolveMultisampleFramebufferAPPLE();
    }
    
    if(isCapableOS4){
        const GLenum discards[]  = {GL_COLOR_ATTACHMENT0_OES,GL_DEPTH_ATTACHMENT_OES};
        glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE,sampleSize,discards);
    }  
    
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, resolveRB);
	[m_context presentRenderbuffer:GL_RENDERBUFFER_OES];
	
}

- (BOOL)createFramebuffers {
    
    // Resolve Layer
    glGenFramebuffersOES(1, &resolveFB);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, resolveFB);
    
    glGenRenderbuffersOES(1, &resolveRB); 
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, resolveRB);
    [m_context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer]; 
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, resolveRB); 
    
    if( isMSAAOn )
        [self createSamplebuffer]; 
    
	return YES;
}


- (void)createSamplebuffer
{
    // Multisample Layer
    glGenFramebuffersOES(1, &sampleFB);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, sampleFB);
    
    glGenRenderbuffersOES( 1, &sampleRB );
    glBindRenderbufferOES( GL_RENDERBUFFER_OES, sampleRB );
    glRenderbufferStorageMultisampleAPPLE( GL_RENDERBUFFER_OES,sampleSize,GL_RGB5_A1_OES, backingWidth, backingHeight );
    glFramebufferRenderbufferOES( GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, sampleRB );
    
    glGenRenderbuffersOES(1, &sampleDB);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, sampleDB);
    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER_OES,sampleSize,GL_DEPTH_COMPONENT24_OES, backingWidth, backingHeight);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, sampleDB);
}


- (void)destroyFramebuffers {
    [self destroySamplebuffer]; 
    
    glDeleteFramebuffersOES(1, &resolveFB);
    resolveFB = 0; 
    
    glDeleteRenderbuffersOES(1,&resolveRB);
    resolveRB = 0;     
}

- (void)destroySamplebuffer {
    glDeleteFramebuffersOES(1, &sampleFB);
	sampleFB = 0;
    
	glDeleteRenderbuffersOES(1, &sampleRB);
	sampleRB = 0;
	
	if(sampleDB) {
		glDeleteRenderbuffersOES(1, &sampleDB);
		sampleDB = 0;
	}     
}

- (void)setInitResScale
{        
    sampleSize = MSAA_LOWER_BOUND; 
    if(sampleSize) isMSAAOn = true; 
    
    if(((CAEAGLLayer *)self.layer).contentsScale > 1.0){        
        ((CAEAGLLayer *)self.layer).contentsScale = 1.1f;
        sampleSize += 1;  
        isMSAAOn = true; 
    }
    resScale = ((CAEAGLLayer *)self.layer).contentsScale; 
}

- (void)optimizeLoResScale 
{
    if(sampleSize > MSAA_LOWER_BOUND){
        sampleSize -= 1; 
        if(!sampleSize){ sampleSize = 0; isMSAAOn = false; } 
    }else{
        if(((CAEAGLLayer *)self.layer).contentsScale > SCL_LOWER_BOUND)
            ((CAEAGLLayer *)self.layer).contentsScale -= SCL_STEP_SIZE; 
        
        if(((CAEAGLLayer *)self.layer).contentsScale < SCL_LOWER_BOUND)
            ((CAEAGLLayer *)self.layer).contentsScale = SCL_LOWER_BOUND; 
    }
    resScale = ((CAEAGLLayer *)self.layer).contentsScale;
    isOptimizationLoNeeded = false; 
}

- (void)optimizeUpResScale 
{  
    if(((CAEAGLLayer *)self.layer).contentsScale < SCL_UPPER_BOUND)
        ((CAEAGLLayer *)self.layer).contentsScale += SCL_STEP_SIZE; 
    else{
        ((CAEAGLLayer *)self.layer).contentsScale = SCL_UPPER_BOUND; 
        
        if(sampleSize < MSAA_UPPER_BOUND)
            sampleSize += 1; 
        
        if(sampleSize > MSAA_UPPER_BOUND)
            sampleSize = MSAA_UPPER_BOUND; 
        
        if (sampleSize) isMSAAOn = true;
    }
    resScale = ((CAEAGLLayer *)self.layer).contentsScale;
    isOptimizationUpNeeded = false;  
}

- (unsigned int) ElapsedTime {
    int time_base = 0;
	struct timeval t;
    
	gettimeofday( &t, NULL );
	time_base =  ( unsigned int )( ( ( ( t.tv_sec * 1000000 ) + t.tv_usec )  /*- itime*/  ) * 0.001 ); 
	return time_base;
}

- (void) setPerspective: (float) _fovy: (float) _aspect: (float) _zNear:(float)_zFar
{
	glMatrixMode( GL_PROJECTION );
	glLoadIdentity();
	{
		float m[ 16 ],
        s,
        c,
        d = _zFar - _zNear,
        r = _fovy * 0.5f * (3.14f / 180.0f);
        
		s = sinf( r );
		c = cosf( r ) / s;
        
		memset( &m[ 0 ], 0, 64 );
        
		m[ 0  ] = c / _aspect;
		m[ 5  ] = c;
		m[ 10 ] = -( _zFar + _zNear ) / d;
		m[ 11 ] = -1.0f;
		m[ 14 ] = -2.0f * _zFar * _zNear / d;
		
		glMultMatrixf( &m[ 0 ] );
	}
	glMatrixMode( GL_MODELVIEW );
	
}

@end
