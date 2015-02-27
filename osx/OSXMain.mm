/*   SDLMain.m - main entry point for our Cocoa-ized SDL app
       Initial Version: Darrell Walisser <dwaliss1@purdue.edu>
       Non-NIB-Code & other changes: Max Horn <max@quendi.de>

    Feel free to customize this file to suit your needs
*/

#include "SDL2/SDL.h"
#import "NSFileManagerDirectoryLocations.h"
#include "ApplicationSupportBridge.h"
#include <sys/param.h> /* for MAXPATHLEN */
#include <unistd.h>

string pLocalApplicationSupportPath;
string pCasesPath;
string pUserApplicationSupportPath;
string pDialogSeenListsPath;
string pSavesPath;

static NSString *NSCasesPath;
static NSString *NSUserCasesPath;
static NSString *NSSavesPath;

/* Main entry point to executable - should *not* be SDL_main! */
void BeginOSX()
{
    @autoreleasepool
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    /* Create our Application Support folders if they don't exist yet and store the paths */
    NSString *localAppSupport = [defaultManager localApplicationSupportDirectory];
    NSString *userAppSupport = [defaultManager userApplicationSupportDirectory];

    /* Next, create the folders that the executable will need during execution if they don't already exist. */
    NSString *localGameAppSupportPath = localAppSupport;
    NSString *userGameAppSupportPath = [userAppSupport stringByAppendingPathComponent:@"My Little Investigations"];
    NSString *dialogSeenPath = [userGameAppSupportPath stringByAppendingPathComponent:@"DialogSeenLists"];

    NSCasesPath = [localGameAppSupportPath stringByAppendingPathComponent:@"Cases"];
    NSUserCasesPath = [userGameAppSupportPath stringByAppendingPathComponent:@"Cases"];
    NSSavesPath = [userGameAppSupportPath stringByAppendingPathComponent:@"Saves"];

	NSError *error = nil;

	[defaultManager
		createDirectoryAtPath:dialogSeenPath
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

    pLocalApplicationSupportPath = [localGameAppSupportPath fileSystemRepresentation];
    pCasesPath = [NSCasesPath fileSystemRepresentation];
    pUserApplicationSupportPath = [userGameAppSupportPath fileSystemRepresentation];
    pDialogSeenListsPath = [dialogSeenPath fileSystemRepresentation];
    pSavesPath = [NSSavesPath fileSystemRepresentation];

}
}

vector<string> GetCaseFilePathsOSX()
{
@autoreleasepool
{
    NSError *error;
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSArray *caseFiles = [defaultManager
                              contentsOfDirectoryAtPath: NSCasesPath
                              error:&error];

    NSMutableArray *uniqueCaseList;
    vector<string> caseFileList;
    NSMutableArray *localCaseList = [[NSMutableArray alloc] initWithCapacity:caseFiles.count];
    
    for (NSString *object in caseFiles)
    {
        //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([object hasPrefix:@"."])
        {
            continue;
        }

        NSString *fullCasePath = [NSCasesPath stringByAppendingPathComponent:object];
        [localCaseList addObject:fullCasePath];
    }

    // Get user cases
    caseFiles = [defaultManager
                     contentsOfDirectoryAtPath:NSUserCasesPath
                     error:&error];
    
    NSMutableArray *userCaseList = [[NSMutableArray alloc] initWithCapacity:caseFiles.count];
    
    for (NSString *object in caseFiles)
    {
        //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([object hasPrefix:@"."])
        {
            continue;
        }
        NSString *fullCasePath = [NSUserCasesPath stringByAppendingPathComponent:object];
        [userCaseList addObject:fullCasePath];
    }
    
    uniqueCaseList = [[NSMutableArray alloc] initWithCapacity:localCaseList.count + userCaseList.count];

    NSIndexSet *uniqueLocalCases = [localCaseList indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        NSString *lastPathComponent = [obj lastPathComponent];
        
        return ![caseFiles containsObject:lastPathComponent];
    }];
    
    [uniqueCaseList addObjectsFromArray:[localCaseList objectsAtIndexes:uniqueLocalCases]];
    [uniqueCaseList addObjectsFromArray:userCaseList];
    
    for (NSString *path in uniqueCaseList)
    {
        caseFileList.push_back(string([path fileSystemRepresentation]));
    }
    
    return caseFileList;
}
}

vector<string> GetSaveFilePathsForCaseOSX(string caseUuid)
{
@autoreleasepool
{
    NSError *error = nil;
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSString *currentCaseSavePath = [NSSavesPath stringByAppendingPathComponent:@(caseUuid.c_str())];

    [defaultManager
     createDirectoryAtPath: currentCaseSavePath
     withIntermediateDirectories:YES
     attributes:nil
     error:&error];
    
    NSArray *pSaveFileList = [defaultManager
                              contentsOfDirectoryAtPath:currentCaseSavePath
                              error:&error];

    vector<string> saveFileList;

    for (NSString *fileName in pSaveFileList)
    {
        //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([fileName hasPrefix:@"."])
        {
            continue;
        }
        
        NSString *savePath = [currentCaseSavePath stringByAppendingPathComponent:fileName];
        saveFileList.push_back(string([savePath fileSystemRepresentation]));
    }

    return saveFileList;
}
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
    @autoreleasepool {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *plistPath = [defaultManager stringWithFileSystemRepresentation:PropertyListFilePath.c_str() length: PropertyListFilePath.size()];
    plistPath = plistPath.stringByStandardizingPath;
    
    if (![defaultManager fileExistsAtPath:plistPath])
    {
        return string();
    }
    
    NSDictionary *plistDict =
    [NSDictionary dictionaryWithContentsOfFile:plistPath];
    
    if (plistDict == NULL) {
        return string();
    }
    
    NSString *versString = plistDict[@"VersionString"];
    return [versString UTF8String];
    }
}

char *GetPropertyListXMLForVersionStringOSX(string PropertyListFilePath, string pVersionString, unsigned long *pVersionStringLength)
{
    *pVersionStringLength = 0;

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *pErrorDesc = nil;
    NSString *plistPath = [defaultManager stringWithFileSystemRepresentation:PropertyListFilePath.c_str() length: PropertyListFilePath.size()];

    if (![defaultManager fileExistsAtPath:plistPath])
    {
        return NULL;
    }

    NSMutableDictionary *plistDict =
        [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];

    if (plistDict == NULL)
    {
        return NULL;
    }

    plistDict[@"VersionString"] = @(pVersionString.c_str());

    NSData *pData = [NSPropertyListSerialization
        dataFromPropertyList:plistDict
        format:NSPropertyListXMLFormat_v1_0
        errorDescription:&pErrorDesc];

    if (pData == NULL)
    {
        return NULL;
    }

    NSUInteger dataLength = [pData length];

    char *pCharData = (char *)malloc(dataLength * sizeof(char));
    [pData getBytes:(void *)pCharData length:dataLength];

    *pVersionStringLength = dataLength;
    return pCharData;
}
