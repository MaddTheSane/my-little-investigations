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
    NSString *pStrLocalApplicationSupportPath;
    @autoreleasepool
    {
        pStrLocalApplicationSupportPath = [defaultManager localApplicationSupportDirectory];
    }
    NSString *pStrUserApplicationSupportPath = [defaultManager userApplicationSupportDirectory];

    /* Next, create the folders that the executable will need during execution if they don't already exist. */
    NSString *pStrLocalGameApplicationSupportPath = pStrLocalApplicationSupportPath;
    NSString *pStrUserGameApplicationSupportPath = [pStrUserApplicationSupportPath stringByAppendingPathComponent:@"My Little Investigations"];
    NSString *pStrDialogSeenListsPath = [pStrUserGameApplicationSupportPath stringByAppendingPathComponent:@"DialogSeenLists"];

    NSCasesPath = [pStrLocalGameApplicationSupportPath stringByAppendingPathComponent:@"Cases"];
    NSUserCasesPath = [pStrUserGameApplicationSupportPath stringByAppendingPathComponent:@"Cases"];
    NSSavesPath = [pStrUserGameApplicationSupportPath stringByAppendingPathComponent:@"Saves"];

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

}
}

vector<string> GetCaseFilePathsOSX()
{
@autoreleasepool
{
    NSError *error;
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    NSArray *pCaseFileList = [defaultManager
                              contentsOfDirectoryAtPath:NSCasesPath
                              error:&error];

    vector<string> ppCaseFileList;

    for (NSString *pStrCaseFileName in pCaseFileList)
    {
        //Ignore UNIX hidden files, like OS X's .DS_Store
        if ([pStrCaseFileName hasPrefix:@"."])
        {
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
        if ([object hasPrefix:@"."])
        {
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
@autoreleasepool
{
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
        if ([pStrSaveFileName hasPrefix:@"."])
        {
            continue;
        }
        
        NSString *pStrSaveFilePath = [currentCaseSavePath stringByAppendingPathComponent:pStrSaveFileName];
        ppSaveFilePathList.push_back(string([pStrSaveFilePath fileSystemRepresentation]));
    }

    return ppSaveFilePathList;
}
}

string GetGameExecutable()
{
    @autoreleasepool
    {
        NSString *exePath = [[[NSFileManager defaultManager] gameBundle] executablePath];
        
        return [exePath fileSystemRepresentation];
    }
}

string GetVersionStringOSX(string PropertyListFilePath)
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *pProperyListPath = [defaultManager stringWithFileSystemRepresentation:PropertyListFilePath.c_str() length: PropertyListFilePath.size()];
    
    if (![defaultManager fileExistsAtPath:pProperyListPath])
    {
        return string();
    }
    
    NSDictionary *pPropertyListDictionary =
    [NSDictionary dictionaryWithContentsOfFile:pProperyListPath];
    
    if (pPropertyListDictionary == NULL) {
        return string();
    }
    
    NSString *pVersionString = pPropertyListDictionary[@"VersionString"];
    return [pVersionString UTF8String];
}

char *GetPropertyListXMLForVersionStringOSX(string PropertyListFilePath, string pVersionString, unsigned long *pVersionStringLength)
{
    *pVersionStringLength = 0;

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *pErrorDesc = nil;
    NSString *pProperyListPath = [defaultManager stringWithFileSystemRepresentation:PropertyListFilePath.c_str() length: PropertyListFilePath.size()];

    if (![defaultManager fileExistsAtPath:pProperyListPath])
    {
        return NULL;
    }

    NSMutableDictionary *pPropertyListDictionaryMutable =
        [NSMutableDictionary dictionaryWithContentsOfFile:pProperyListPath];

    if (pPropertyListDictionaryMutable == NULL)
    {
        return NULL;
    }

    pPropertyListDictionaryMutable[@"VersionString"] = @(pVersionString.c_str());

    NSData *pData = [NSPropertyListSerialization
        dataFromPropertyList:pPropertyListDictionaryMutable
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
