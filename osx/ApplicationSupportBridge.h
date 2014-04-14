#ifndef APPLICATIONSUPPORTBRIDGE_H
#define APPLICATIONSUPPORTBRIDGE_H

#include <string>
#include <vector>

extern const char *pLocalApplicationSupportPath;
extern const char *pCasesPath;
extern const char *pUserApplicationSupportPath;
extern const char *pDialogSeenListsPath;
extern const char *pSavesPath;

std::vector<std::string> GetSaveFilePathsForCaseOSX(std::string caseUuid);
std::vector<std::string> GetCaseFilePathsOSX();
std::string GetVersionStringOSX(std::string PropertyListFilePath);
char * GetPropertyListXMLForVersionStringOSX(std::string pPropertyListFilePath, std::string pVersionString, unsigned long *pVersionStringLength);
std::string GetGameExecutable();

#endif
