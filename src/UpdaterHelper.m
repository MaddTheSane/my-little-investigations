/**
 * (OS X only) Utility executable for performing update operations as root.
 *
 * @author GabuEx, dawnmew, Madd the Sane
 * @since 1.0
 *
 * Licensed under the MIT License.
 *
 * Copyright (c) 2012 Equestrian Dreamers
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Foundation/Foundation.h>

#define PRINT_AND_RETURN() \
	do { \
		int returnValue = success ? 0 : 1; \
		fprintf(stdout, "Return value: %u\n", returnValue); \
		return returnValue; \
	} while (0)


int main(int argc, char *argv[])
{
	BOOL success = NO;
	NSProcessInfo *pi = [NSProcessInfo processInfo];
	
	// If we have no arguments at all, we'll just bail.
	if (argc < 2) {
		fprintf(stderr, "UpdaterHelper: This is a utility executable to be run by MyLittleInvestigationsUpdater. It is not intended to be run in isolation, and will do nothing if it is.\n");
		PRINT_AND_RETURN();
	}
	NSArray *args = pi.arguments;
	
	NSString *operation = args[1];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([operation isEqualToString:@"update"]) {
		// If we're updating, we expect to receive three additional arguments:
		// the old file path, the delta file path, and the new file path.
		if (argc < 5) {
			fprintf(stderr, "UpdaterHelper: Expected 5 arguments for update operation, but only received %u.\n", argc);
			PRINT_AND_RETURN();
		}
		
		NSString *launcherFilePath = args[0];
		NSString *updaterFileDir = [launcherFilePath stringByDeletingLastPathComponent];
		NSString *updaterFilePath = [updaterFileDir stringByAppendingPathComponent:@"deltatool"];
		updaterFilePath = [updaterFilePath stringByAppendingPathComponent:@"xdelta3"];
		
		NSString *oldFilePath = args[2];
		NSString *deltaFilePath = args[3];
		NSString *newFilePath = args[4];
		
		@autoreleasepool {
			NSArray *commandLineArguments = @[@"-f", @"-d", @"-s", oldFilePath, deltaFilePath, newFilePath];
			
			NSTask *process = [NSTask new];
			process.launchPath = updaterFilePath;
			process.arguments = commandLineArguments;
			@try {
				[process launch];
				[process waitUntilExit];
				
				success = process.terminationStatus == 0;
			}
			@catch (NSException *exception) {
				success = NO;
				fprintf(stderr, "UpdaterHelper: NSTask raised an exception: name: '%s' reason: '%s'.\n", exception.name.UTF8String, exception.reason.UTF8String);
			}
		}
		
		if (success) {
			short perms = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;
			success = [fm setAttributes:@{NSFilePosixPermissions: @(perms)} ofItemAtPath:newFilePath error:nil];
		}
	} else if ([operation isEqualToString:@"remove"]) {
		// If we're removing, we expect to receive one additional argument:
		// the file path to remove.
		if (argc < 3) {
			fprintf(stderr, "UpdaterHelper: Expected 3 arguments for remove operation, but only received %d.\n", argc);
			PRINT_AND_RETURN();
		}

		NSString *filePath = args[2];
		
		success = [fm removeItemAtPath:filePath error:nil];
	} else if ([operation isEqualToString:@"rename"]) {
		// If we're renaming, we expect to receive two additional arguments:
		// the old file path and the new file path.
		if (argc < 4) {
			fprintf(stderr, "UpdaterHelper: Expected 4 arguments for rename operation, but only received %d.\n", argc);
			PRINT_AND_RETURN();
		}
		
		NSString *oldFilePath = args[2];
		NSString *newFilePath = args[3];

		success = [fm moveItemAtPath:oldFilePath toPath:newFilePath error:nil];
	} else {
		fprintf(stderr, "UpdaterHelper: Unknown operation '%s'.\n", argv[1]);
		PRINT_AND_RETURN();
	}
	
	PRINT_AND_RETURN();
}
