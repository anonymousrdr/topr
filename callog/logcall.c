# include <stdio.h>

//easier to create LLVM call instr to this fn than printf (has an extra %s arg)
//easier to get pointer to fn defined in code/module
void loggerfn(char* logarg1, char* logarg2)
{
    FILE *f1 = fopen("tracecall.txt", "a");
    fprintf(f1, "%s ===> %s\n", logarg1, logarg2);
    fclose(f1);
}
