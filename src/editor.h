
void initialize(const char* sysdir);

int read_edit(char* prompt, char* line);

int read_cmd(char* prompt);

int read_file(char* prompt);

char* get_last_result(void);

void finalize(void);
