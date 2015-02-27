//
//  NSFileManager+DirectoryLocations.m
//
//  Created by Matt Gallagher on 06 May 2010
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

#import "NSFileManagerDirectoryLocations.h"

enum
{
	DirectoryLocationErrorNoPathFound,
	DirectoryLocationErrorFileExistsAtLocation
};

NSString * const DirectoryLocationDomain = @"DirectoryLocationDomain";

@implementation NSFileManager (DirectoryLocations)

//
// findOrCreateDirectory:inDomain:appendPathComponent:error:
//
// Method to tie together the steps of:
//	1) Locate a standard directory by search path and domain mask
//  2) Select the first path in the results
//	3) Append a subdirectory to that path
//	4) Create the directory and intermediate directories if needed
//	5) Handle errors by emitting a proper NSError object
//
// Parameters:
//    searchPathDirectory - the search path passed to NSSearchPathForDirectoriesInDomains
//    domainMask - the domain mask passed to NSSearchPathForDirectoriesInDomains
//    appendComponent - the subdirectory appended
//    errorOut - any error from file operations
//
// returns the path to the directory (if path found and exists), nil otherwise
//
- (NSString *)findOrCreateDirectory:(NSSearchPathDirectory)searchPathDirectory
	inDomain:(NSSearchPathDomainMask)domainMask
	appendPathComponent:(NSString *)appendComponent
	error:(NSError **)errorOut
{
	//
	// Search for the path
	//
	NSArray* paths = NSSearchPathForDirectoriesInDomains(
		searchPathDirectory,
		domainMask,
		YES);
	if ([paths count] == 0)
	{
		if (errorOut)
		{
			NSDictionary *userInfo =
				@{NSLocalizedDescriptionKey: NSLocalizedStringFromTable(
						@"No path found for directory in domain.",
						@"Errors",
					nil),
					@"NSSearchPathDirectory": @(searchPathDirectory),
					@"NSSearchPathDomainMask": @(domainMask)};
			*errorOut =
				[NSError
					errorWithDomain:DirectoryLocationDomain
					code:DirectoryLocationErrorNoPathFound
					userInfo:userInfo];
		}
		return nil;
	}

	//
	// Normally only need the first path returned
	//
	NSString *resolvedPath = paths[0];

	//
	// Append the extra path component
	//
	if (appendComponent)
	{
		resolvedPath = [resolvedPath
			stringByAppendingPathComponent:appendComponent];
	}

	//
	// Create the path if it doesn't exist
	//
	NSError *error = nil;
	BOOL success = [self
		createDirectoryAtPath:resolvedPath
		withIntermediateDirectories:YES
		attributes:nil
		error:&error];
	if (!success)
	{
		if (errorOut)
		{
			*errorOut = error;
		}
		return nil;
	}

	//
	// If we've made it this far, we have a success
	//
	if (errorOut)
	{
		*errorOut = nil;
	}
	return resolvedPath;
}

//
// userApplicationSupportDirectory
//
// Returns the path to the userApplicationSupportDirectory (creating it if it doesn't
// exist).
//
- (NSString *)userApplicationSupportDirectory
{
	NSError *error;
	NSString *result =
		[self
			findOrCreateDirectory:NSApplicationSupportDirectory
			inDomain:NSUserDomainMask
			appendPathComponent:nil
			error:&error];
	if (!result)
	{
		NSLog(@"Unable to find or create application support directory:\n%@", error);
	}
	return result;
}

- (NSBundle *)gameBundle
{
	//Load resources from the game bundle.
#ifdef GAME_EXECUTABLE
	//We are the game bundle
	return [NSBundle mainBundle];
#else
	//Find the game bundle.
	NSBundle *mainbundle = [NSBundle mainBundle];
	//First, look in our resources directory
	NSArray *dirArray = [self contentsOfDirectoryAtPath:[mainbundle resourcePath]
												  error:NULL];
	if (dirArray)
	{
		for (NSString *subContent in dirArray)
		{
			NSBundle *theBundle = [NSBundle bundleWithPath:subContent];
			if (theBundle && [[theBundle bundleIdentifier] isEqualToString:@"com.EquestrianDreamers.MyLittleInvestigations"])
			{
				//Yay, we found it!
				return theBundle;
			}
		}
	}
	
	//We haven't found it yet, so we'll search the same directory that the app is in first
	dirArray = [self contentsOfDirectoryAtPath:[[mainbundle bundlePath] stringByDeletingLastPathComponent] error:NULL];
	for (NSString *subContent in dirArray)
	{
		NSBundle *theBundle = [NSBundle bundleWithPath:subContent];
		if (theBundle && [[theBundle bundleIdentifier] isEqualToString:@"com.EquestrianDreamers.MyLittleInvestigations"])
		{
			//Yay, we found it!
			return theBundle;
		}
	}
	
	//last-ditch effort!
	NSBundle *locateBundleExpensively = [NSBundle bundleWithIdentifier:@"com.EquestrianDreamers.MyLittleInvestigations"];
	if (locateBundleExpensively) {
		return locateBundleExpensively;
	}
	
	//We could not find it!
	return nil;
#endif

}

//
// localApplicationSupportDirectory
//
// Returns the path to the localApplicationSupportDirectory (creating it if it doesn't
// exist).
//
- (NSString *)localApplicationSupportDirectory
{
#if 1
	return [[self gameBundle] resourcePath];
#else
	return [[NSBundle mainBundle] resourcePath];
#endif
}

@end
