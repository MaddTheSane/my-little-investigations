#ifndef APPLICATIONSUPPORTBRIDGE_H
#define APPLICATIONSUPPORTBRIDGE_H

extern const char *pLocalApplicationSupportPath;
extern const char *pCasesPath;
extern const char *pUserApplicationSupportPath;
extern const char *pDialogSeenListsPath;
extern const char *pSavesPath;

vector<string> GetSaveFilePathsForCaseOSX(string caseUuid);
vector<string> GetCaseFilePathsOSX();
string GetVersionStringOSX(string PropertyListFilePath);
char * GetPropertyListXMLForVersionStringOSX(const char *pPropertyListFilePath, const char *pVersionString, unsigned long *pVersionStringLength);

#endif
