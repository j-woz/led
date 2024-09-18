
#define _GNU_SOURCE // for asprintf()
#include <assert.h>
#include <getopt.h>
#include <signal.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <readline/readline.h>
#include <readline/history.h>

#include "src/editor.h"

static char* line_original = NULL;
static char* last_result = NULL;

static char* history_edit    = NULL;
static char* history_command = NULL;
static char* history_fs      = NULL;
static char* history_eval    = NULL;

static int my_revert(int,int);
static int startup_hook(void);

typedef enum { NONE, EDIT, COMMAND, FS } history_mode;
history_mode history_mode_current;

void
initialize(const char* sysdir)
{
  rl_add_defun("my-revert", my_revert, -1);
  rl_startup_hook = (rl_hook_func_t *) startup_hook;

  int n;
  n = asprintf(&history_edit,    "%s/edit.history",    sysdir);
  assert(n > 0);
  n = asprintf(&history_command, "%s/command.history", sysdir);
  assert(n > 0);
  n = asprintf(&history_fs,      "%s/fs.history",      sysdir);
  assert(n > 0);
  n = asprintf(&history_eval,    "%s/eval.history",    sysdir);
  assert(n > 0);

  history_mode_current = NONE;
}

static int
startup_hook()
{
  rl_insert_text(line_original);
  return 0;
}

int
read_edit(char* prompt, char* line)
{
  if (history_mode_current != EDIT)
  {
    read_history(history_edit);
    history_mode_current = EDIT;
  }
  line_original = line;
  last_result = readline(prompt);
  add_history(last_result);
  append_history(1, history_edit);

  return 1;
}

int
read_cmd(char* prompt)
{
  if (history_mode_current != COMMAND)
  {
    read_history(history_command);
    history_mode_current = COMMAND;
  }
  line_original = "";
  last_result = readline(prompt);
  add_history(last_result);
  append_history(1, history_command);
  return 1;
}

int
read_file(char* prompt)
{
  if (history_mode_current != FS)
  {
    read_history(history_fs);
    history_mode_current = FS;
  }

  // Configure readline to auto-complete paths
  // when the tab key is hit.
  rl_bind_key('\t', rl_complete);
  last_result = readline(prompt);
  return 1;
}

char*
get_last_result()
{
  return last_result;
}

static int
my_revert(int _v1, int _v2)
{
  rl_delete_text(0, strlen(rl_line_buffer));
  rl_beg_of_line(0, 0);
  rl_insert_text(line_original);
  rl_redisplay();
}

void
finalize()
{
  if (last_result != NULL)
    free(last_result);
  free(history_edit);
  free(history_fs);
  free(history_command);
}
