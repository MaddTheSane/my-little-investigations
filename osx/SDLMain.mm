/*   SDLMain.m - main entry point for our Cocoa-ized SDL app
       Initial Version: Darrell Walisser <dwaliss1@purdue.edu>
       Non-NIB-Code & other changes: Max Horn <max@quendi.de>

    Feel free to customize this file to suit your needs
*/

#include "SDL2/SDL.h"
#import "SDLMain.h"
#import "NSFileManagerDirectoryLocations.h"
#include "ApplicationSupportBridge.h"
#include <sys/param.h> /* for MAXPATHLEN */
#include <unistd.h>

using namespace std;

/* For some reaon, Apple removed setAppleMenu from the headers in 10.4,
 but the method still is there and works. To avoid warnings, we declare
 it ourselves here. */
@interface NSApplication(SDL_Missing_Methods)
- (void)setAppleMenu:(NSMenu *)menu;
@end

/* Use this flag to determine whether we use SDLMain.nib or not */
#define		SDL_USE_NIB_FILE	0

/* Use this flag to determine whether we use CPS (docking) or not */
#define		SDL_USE_CPS		1
#ifdef SDL_USE_CPS
/* Portions of CPS.h */
typedef struct CPSProcessSerNum
{
	UInt32		lo;
	UInt32		hi;
} CPSProcessSerNum;

extern "C" {
extern OSErr	CPSGetCurrentProcess( CPSProcessSerNum *psn);
extern OSErr 	CPSEnableForegroundOperation( CPSProcessSerNum *psn, UInt32 _arg2, UInt32 _arg3, UInt32 _arg4, UInt32 _arg5);
extern OSErr	CPSSetFrontProcess( CPSProcessSerNum *psn);
}

#endif /* SDL_USE_CPS */

static int    gArgc;
static char  **gArgv;
static BOOL   gFinderLaunch;
static BOOL   gCalledAppMainline = NO;

static NSString *NSCasesPath;
static NSString *NSUserCasesPath;
static NSString *NSSavesPath;

static NSString *getApplicationName(void)
{
    const NSDictionary *dict;
    NSString *appName = 0;

    /* Determine the application name */
    dict = (__bridge const NSDictionary *)CFBundleGetInfoDictionary(CFBundleGetMainBundle());
    if (dict)
        appName = [dict objectForKey: @"CFBundleName"];

    if (![appName length])
        appName = [[NSProcessInfo processInfo] processName];

    return appName;
}

#if SDL_USE_NIB_FILE
/* A helper category for NSString */
@interface NSString (ReplaceSubString)
- (NSString *)stringByReplacingRange:(NSRange)aRange with:(NSString *)aString;
@end
#endif

@interface SDLApplication : NSApplication
@end

@implementation SDLApplication
/* Invoked from the Quit menu item */
- (void)terminate:(id)sender
{
    /* Post a SDL_QUIT event */
    SDL_Event event;
    event.type = SDL_QUIT;
    SDL_PushEvent(&event);
}
@end

/* The main class of the application, the application's delegate */
@implementation SDLMain

/* Set the working directory to the .app's resource directory */
- (void) setupWorkingDirectory:(BOOL)shouldChdir
{
    if (shouldChdir)
    {
        chdir([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]);
        chdir("Contents/Resources");
    }
}

#if SDL_USE_NIB_FILE

/* Fix menu to contain the real app name instead of "SDL App" */
- (void)fixMenu:(NSMenu *)aMenu withAppName:(NSString *)appName
{
    NSRange aRange;
    NSEnumerator *enumerator;
    NSMenuItem *menuItem;

    aRange = [[aMenu title] rangeOfString:@"SDL App"];
    if (aRange.length != 0)
        [aMenu setTitle: [[aMenu title] stringByReplacingRange:aRange with:appName]];

    enumerator = [[aMenu itemArray] objectEnumerator];
    while ((menuItem = [enumerator nextObject]))
    {
        aRange = [[menuItem title] rangeOfString:@"SDL App"];
        if (aRange.length != 0)
            [menuItem setTitle: [[menuItem title] stringByReplacingRange:aRange with:appName]];
        if ([menuItem hasSubmenu])
            [self fixMenu:[menuItem submenu] withAppName:appName];
    }
}

#else

static void setApplicationMenu(void)
{
    /* warning: this code is very odd */
    NSMenu *appleMenu;
    NSMenuItem *menuItem;
    NSString *title;
    NSString *appName = getApplicationName();
    appleMenu = [[NSMenu alloc] initWithTitle:@""];

    /* Add menu items */
    title = [@"About " stringByAppendingString:appName];
    [appleMenu addItemWithTitle:title action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

    [appleMenu addItem:[NSMenuItem separatorItem]];

    title = [@"Hide " stringByAppendingString:appName];
    [appleMenu addItemWithTitle:title action:@selector(hide:) keyEquivalent:@"h"];

    menuItem = (NSMenuItem *)[appleMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [menuItem setKeyEquivalentModifierMask:(NSAlternateKeyMask|NSCommandKeyMask)];

    [appleMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];

    [appleMenu addItem:[NSMenuItem separatorItem]];

    title = [@"Quit " stringByAppendingString:appName];
    [appleMenu addItemWithTitle:title action:@selector(terminate:) keyEquivalent:@"q"];


    /* Put menu into the menubar */
    menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [menuItem setSubmenu:appleMenu];
    [[NSApp mainMenu] addItem:menuItem];

    /* Tell the application object that this is now the application menu */
    [NSApp setAppleMenu:appleMenu];
}

/* Create a window menu */
static void setupWindowMenu(void)
{
    NSMenu      *windowMenu;
    NSMenuItem  *windowMenuItem;
    NSMenuItem  *menuItem;

    windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    /* "Minimize" item */
    menuItem = [[NSMenuItem alloc] initWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItem:menuItem];

    /* Put menu into the menubar */
    windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [windowMenuItem setSubmenu:windowMenu];
    [[NSApp mainMenu] addItem:windowMenuItem];

    /* Tell the application object that this is now the window menu */
    [NSApp setWindowsMenu:windowMenu];

    /* Finally give up our references to the objects */
}

/* Replacement for NSApplicationMain */
static void CustomApplicationMain (int argc, char **argv)
{
@autoreleasepool {
    SDLMain				*sdlMain;

    /* Ensure the application object is initialised */
    [NSApplication sharedApplication];

#ifdef SDL_USE_CPS
    {
        CPSProcessSerNum PSN;
        /* Tell the dock about us */
        if (!CPSGetCurrentProcess(&PSN))
            if (!CPSEnableForegroundOperation(&PSN,0x03,0x3C,0x2C,0x1103))
                if (!CPSSetFrontProcess(&PSN))
                    [SDLApplication sharedApplication];
    }
#endif /* SDL_USE_CPS */

    /* Set up the menubar */
    [NSApp setMainMenu:[[NSMenu alloc] init]];
    setApplicationMenu();
    setupWindowMenu();

    /* Create SDLMain and make it the app delegate */
    sdlMain = [[SDLMain alloc] init];
    [NSApp setDelegate:sdlMain];

    /* Start the main event loop */
    [NSApp run];
}
}

#endif


/*
 * Catch document open requests...this lets us notice files when the app
 *  was launched by double-clicking a document, or when a document was
 *  dragged/dropped on the app's icon. You need to have a
 *  CFBundleDocumentsType section in your Info.plist to get this message,
 *  apparently.
 *
 * Files are added to gArgv, so to the app, they'll look like command line
 *  arguments. Previously, apps launched from the finder had nothing but
 *  an argv[0].
 *
 * This message may be received multiple times to open several docs on launch.
 *
 * This message is ignored once the app's mainline has been called.
 */
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    //TODO: use SDL2's native file handling, if it has any.
    /* app has not started, ignore this document. */
    if (!gFinderLaunch && !gCalledAppMainline)  /* MacOS is passing command line args. */
        return NO;

    BOOL isDir;
    if (![defaultManager fileExistsAtPath:filename isDirectory:&isDir] || isDir) {
        return NO;
    }

    // move the opened case file to the user's case directory
    if ([[filename pathExtension] compare:@"mlicase" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        NSString *userCaseFile = [NSUserCasesPath stringByAppendingPathComponent:[filename lastPathComponent]];
        if ([defaultManager fileExistsAtPath:userCaseFile]) {
            NSRunAlertPanel(@"Existing Case Found", @"There is already a case with the UUID \"%@\" in your user folder.\nYou need to delete it manually if you wish to replace it", nil, nil, nil, [[filename lastPathComponent] stringByDeletingPathExtension]);
            return NO;
        }
        return [defaultManager copyItemAtPath:filename toPath:userCaseFile error:NULL];
    }
    
    return NO;
}


/* Called when the internal event loop has just started running */
- (void) applicationDidFinishLaunching: (NSNotification *) note
{
    int status;

    /* Set the working directory to the .app's parent directory */
    [self setupWorkingDirectory:gFinderLaunch];

#if SDL_USE_NIB_FILE
    /* Set the main menu to contain the real app name instead of "SDL App" */
    [self fixMenu:[NSApp mainMenu] withAppName:getApplicationName()];
#endif

    /* Hand off to main application code */
    gCalledAppMainline = TRUE;
    status = SDL_main (gArgc, gArgv);

    /* We're done, thank you for playing */
    exit(status);
}
@end

@implementation NSString (ReplaceSubString)

- (NSString *)stringByReplacingRange:(NSRange)aRange with:(NSString *)aString
{
    NSUInteger bufferSize;
    NSUInteger selfLen = [self length];
    NSUInteger aStringLen = [aString length];
    unichar *buffer;
    NSRange localRange;
    NSString *result;

    bufferSize = selfLen + aStringLen - aRange.length;
    buffer = (unichar *)NSAllocateMemoryPages(bufferSize*sizeof(unichar));

    /* Get first part into buffer */
    localRange.location = 0;
    localRange.length = aRange.location;
    [self getCharacters:buffer range:localRange];

    /* Get middle part into buffer */
    localRange.location = 0;
    localRange.length = aStringLen;
    [aString getCharacters:(buffer+aRange.location) range:localRange];

    /* Get last part into buffer */
    localRange.location = aRange.location + aRange.length;
    localRange.length = selfLen - localRange.location;
    [self getCharacters:(buffer+aRange.location+aStringLen) range:localRange];

    /* Build output string */
    result = [NSString stringWithCharacters:buffer length:bufferSize];

    NSDeallocateMemoryPages(buffer, bufferSize);

    return result;
}

@end

#ifdef main
#  undef main
#endif

/* Main entry point to executable - should *not* be SDL_main! */
int main (int argc, char **argv)
{
    NSAutoreleasePool *pPool = [[NSAutoreleasePool alloc] init];
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    /* Create our Application Support folders if they don't exist yet and store the paths */
    NSString *pStrLocalApplicationSupportPath;
    {
        NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
        pStrLocalApplicationSupportPath = [[defaultManager localApplicationSupportDirectory] retain];
        [innerPool drain];
    }
    NSString *pStrUserApplicationSupportPath = [defaultManager userApplicationSupportDirectory];

    /* Next, create the folders that the executable will need during execution if they don't already exist. */
    NSString *pStrLocalGameApplicationSupportPath = [pStrLocalApplicationSupportPath autorelease];
    NSString *pStrUserGameApplicationSupportPath = [pStrUserApplicationSupportPath stringByAppendingPathComponent:@"My Little Investigations"];
    NSString *pStrDialogSeenListsPath = [pStrUserGameApplicationSupportPath stringByAppendingPathComponent:@"DialogSeenLists"];

    NSCasesPath = [[pStrLocalGameApplicationSupportPath stringByAppendingPathComponent:@"Cases"] retain];
    NSSavesPath = [[pStrUserGameApplicationSupportPath stringByAppendingPathComponent:@"Saves"] retain];
    NSUserCasesPath = [[pStrUserGameApplicationSupportPath stringByAppendingPathComponent:@"Cases"] retain];

    NSError *error;

    [defaultManager
     createDirectoryAtPath:pStrDialogSeenListsPath
     withIntermediateDirectories:YES
     attributes:nil
     error:&error];

    [defaultManager
     createDirectoryAtPath:NSSavesPath
     withIntermediateDirectories:YES
     attributes:nil
     error:&error];

    [defaultManager
     createDirectoryAtPath:NSUserCasesPath
     withIntermediateDirectories:YES
     attributes:nil
     error:&error];

    pLocalApplicationSupportPath = [pStrLocalGameApplicationSupportPath fileSystemRepresentation];
    pCasesPath = [NSCasesPath fileSystemRepresentation];
    pUserApplicationSupportPath = [pStrUserGameApplicationSupportPath fileSystemRepresentation];
    pDialogSeenListsPath = [pStrDialogSeenListsPath fileSystemRepresentation];
    pSavesPath = [NSSavesPath fileSystemRepresentation];

    /* Copy the arguments into a global variable */
    /* This is passed if we are launched by double-clicking */
    if ( argc >= 2 && strncmp (argv[1], "-psn", 4) == 0 ) {
        gArgv = (char **) SDL_malloc(sizeof (char *) * 2);
        gArgv[0] = argv[0];
        gArgv[1] = NULL;
        gArgc = 1;
        gFinderLaunch = YES;
    } else if(argc == 1) {
        //OS X 10.9 and later does /this/
        const char *cwd = getcwd(NULL, 0);
        if (strcmp(cwd, "/") != 0) {
            goto notMavericks;
        }
        
        gArgv = (char **) SDL_malloc(sizeof (char *) * 2);
        gArgv[0] = argv[0];
        gArgv[1] = NULL;
        gArgc = 1;
        gFinderLaunch = YES;
    } else {
    notMavericks:
        int i;
        gArgc = argc;
        gArgv = (char **) SDL_malloc(sizeof (char *) * (argc+1));
        for (i = 0; i <= argc; i++)
            gArgv[i] = argv[i];
        gFinderLaunch = NO;
    }

#if SDL_USE_NIB_FILE
    NSApplicationMain (argc, argv);
#else
    CustomApplicationMain (argc, argv);
#endif

}
    return 0;
}

vector<string> GetCaseFilePathsOSX()
{
    @autoreleasepool {
    NSError *error;
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSArray *pCaseFileList = [defaultManager
     contentsOfDirectoryAtPath:NSCasesPath
     error:&error];

    vector<string> ppCaseFileList;

    for (NSString *pStrCaseFileName in pCaseFileList)
    {
        //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([pStrCaseFileName hasPrefix:@"."]) {
            continue;
        }

        NSString *pStrCaseFilePath = [NSCasesPath stringByAppendingPathComponent:pStrCaseFileName];
		ppCaseFileList.push_back(string([pStrCaseFilePath fileSystemRepresentation]));
    }

    pCaseFileList = [defaultManager
     contentsOfDirectoryAtPath:NSUserCasesPath
     error:&error];

    for (NSString *object in pCaseFileList)
    {
        //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([object hasPrefix:@"."]) {
            continue;
        }
        NSString *fullCasePath = [NSUserCasesPath stringByAppendingPathComponent:object];
		ppCaseFileList.push_back(string([fullCasePath fileSystemRepresentation]));
    }

    return ppCaseFileList;
    }
}

vector<string> GetSaveFilePathsForCaseOSX(string caseUuid)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSError *error = nil;
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    
    NSString *currentCaseSavePath = [NSSavesPath stringByAppendingPathComponent:@(caseUuid.c_str())];
    
    [defaultManager
     createDirectoryAtPath:currentCaseSavePath
     withIntermediateDirectories:YES
     attributes:nil
     error:&error];
    
    NSArray *pSaveFileList = [defaultManager
                              contentsOfDirectoryAtPath:currentCaseSavePath
                              error:&error];

    vector<string> ppSaveFilePathList;

    for (NSString *pStrSaveFileName in pSaveFileList)
    {
       //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([pStrSaveFileName hasPrefix:@"."]) {
            continue;
        }

        NSString *pStrSaveFilePath = [NSSavesPath stringByAppendingPathComponent:pStrSaveFileName];
		ppSaveFilePathList.push_back(string([pStrSaveFilePath fileSystemRepresentation]));
    }

    [pool drain];
    return ppSaveFilePathList;
}

string GetGameExecutable()
{
    @autoreleasepool {
        NSString *exePath = [[[NSFileManager defaultManager] gameBundle] executablePath];
        
        return [exePath fileSystemRepresentation];
    }
}

string GetVersionStringOSX(string PropertyListFilePath)
{
    NSString *pErrorDesc;
    NSPropertyListFormat format;
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    const char *pPropertyListFilePath = PropertyListFilePath.c_str();
    NSString *pProperyListPath = [defaultManager stringWithFileSystemRepresentation:pPropertyListFilePath length:strlen(pPropertyListFilePath)];

    if (![defaultManager fileExistsAtPath:pProperyListPath])
    {
        return string();
    }

    NSData *pPropertyListXML = [[NSFileManager defaultManager] contentsAtPath:pProperyListPath];
    NSDictionary *pPropertyListDictionary =
    [NSPropertyListSerialization propertyListFromData:pPropertyListXML
                                                     mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                               format:&format
                                                     errorDescription:&pErrorDesc];

    if (pPropertyListDictionary == NULL)
    {
        return string();
    }

    NSString *pVersionString = [pPropertyListDictionary objectForKey:@"VersionString"];
    return [pVersionString UTF8String];
}

char *GetPropertyListXMLForVersionStringOSX(string PropertyListFilePath, string pVersionString, unsigned long *pVersionStringLength)
{
    *pVersionStringLength = 0;

    NSString *pErrorDesc;
    NSPropertyListFormat format;
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    const char * pPropertyListFilePath = PropertyListFilePath.c_str();
    NSString *ProperyListPath = [defaultManager stringWithFileSystemRepresentation:pPropertyListFilePath length:strlen(pPropertyListFilePath)];
	
    if (![[NSFileManager defaultManager] fileExistsAtPath:ProperyListPath])
    {
        return NULL;
    }

    NSData *pPropertyListXML = [NSData dataWithContentsOfFile:ProperyListPath];
    NSDictionary *pPropertyListDictionary =
        (NSDictionary *)[NSPropertyListSerialization propertyListFromData:pPropertyListXML
            mutabilityOption:NSPropertyListMutableContainersAndLeaves
            format:&format
            errorDescription:&pErrorDesc];

    if (pPropertyListDictionary == NULL)
    {
        return NULL;
    }

    NSMutableDictionary *pPropertyListDictionaryMutable = [pPropertyListDictionary mutableCopy];

    [pPropertyListDictionaryMutable setObject:@(pVersionString.c_str()) forKey:@"VersionString"];

    NSData *pData = [NSPropertyListSerialization
        dataFromPropertyList:(id)pPropertyListDictionaryMutable
        format:NSPropertyListXMLFormat_v1_0
        errorDescription:&pErrorDesc];

    if (pData == NULL)
    {
        return NULL;
    }

    unsigned long dataLength = [pData length];

    char *pCharData = (char *)malloc(dataLength * sizeof(char));
    [pData getBytes:(void *)pCharData length:dataLength];

    *pVersionStringLength = dataLength;
    return pCharData;
}
