#ifndef APPLICATIONSUPPORTBRIDGE_H
#define APPLICATIONSUPPORTBRIDGE_H

#include <string>
#include <vector>

using namespace std;

extern string pLocalApplicationSupportPath;
extern string pCasesPath;
extern string pUserApplicationSupportPath;
extern string pDialogSeenListsPath;
extern string pSavesPath;

std::vector<std::string> GetCaseFilePathsOSX();
std::vector<std::string> GetSaveFilePathsForCaseOSX(std::string caseUuid);
std::string GetVersionStringOSX(std::string PropertyListFilePath);
char * GetPropertyListXMLForVersionStringOSX(std::string pPropertyListFilePath, std::string pVersionString, unsigned long *pVersionStringLength);
std::string GetGameExecutable();

#endif
