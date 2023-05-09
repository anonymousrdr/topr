import sys
import re

cfile = sys.argv[1]

cfilepath = cfile.rsplit('/', 2)
cfilepdir = cfilepath[0]
prefx = cfilepath[-2]
# only count errors on paths to target using inputs that reach target in 'aflgo-replay-cov.sh + target-info-parser.py' analysis
tinp = open(cfilepdir+"/targ-ips.txt")
tinplist = tinp.readlines()
tinp.close()

# filter out unique errors based on full stacktrace -> error type, error lines
ucr_full_stack_no_irrelev = list()
ucr_full_stack = list()

# filter out unique errors based on primary line number in project -> error type, error line
ucr_loc1line_no_irrelev = list()
ucr_loc1line = list()

# number of non-leak errors
nlefs = 0    
nlel1 = 0

fp = open(cfile, errors="ignore")
lines = fp.readlines()
indx = 0
line_count = len(lines)
while(indx < line_count):
    line = lines[indx]
    line = line.strip()
    indx = indx + 1
    if(line == ''):
        continue
    if("INPUT: " in line):
        isNonLeakError = False
        subline = "INPUT: " + line[line.index("/out/")+1:] + "\n"
        full_stack = subline
        loc1line = subline
        thisinp = (line.split(" ")[1]) + "\n"
        if(thisinp not in tinplist): # input does not reach target so skip tracking error
            while(indx < line_count):
                line = lines[indx]
                line = line.strip()
                indx = indx + 1
                if(len(line)==0):
                    continue
                if("END OF REPLAY----" in line):
                    break
    elif("==ERROR:" in line):
        if("==ERROR: LeakSanitizer:" not in line):
            isNonLeakError = True
        full_stack = full_stack + line + "\n"
        loc1line = loc1line + line + "\n"
        linesplits = line.split(" ")
        errline_edit = "==ERROR: " + linesplits[1] + " " + linesplits[2]  + "\n"
        full_stack_no_irrelev = errline_edit
        loc1line_no_irrelev = errline_edit
        getLoc1 = True
        while(indx < line_count):
            line = lines[indx]
            line = line.strip()
            indx = indx + 1
            if(len(line)==0):
                continue
            if("END OF REPLAY----" in line):
                break
            line_edit = re.sub('/home/.+aflgo-replay/', '', line)
            full_stack = full_stack + line_edit + "\n"
            if(("#" == line_edit[0]) and (" in " in line_edit)): # only use lines starting with '#' to find unique stack trace
                subline_edit = line_edit[line_edit.index(" in ")+1:]
                full_stack_no_irrelev = full_stack_no_irrelev + subline_edit + "\n"
                # get primary error location in project - not /lib/asan/ or __libc_start_main
                if( (getLoc1) and ("/lib/asan/" not in line_edit) and ("__libc_start_main" not in line_edit) and (":" in line_edit) ):
                    getLoc1 = False
                    loc1line = loc1line + line_edit + "\n"
                    loc1line_no_irrelev = loc1line_no_irrelev + subline_edit + "\n"
        if(full_stack_no_irrelev not in ucr_full_stack_no_irrelev):
            ucr_full_stack_no_irrelev.append(full_stack_no_irrelev)
            ucr_full_stack.append(full_stack)
            if(isNonLeakError):
                nlefs = nlefs + 1
        if(loc1line_no_irrelev not in ucr_loc1line_no_irrelev):
            ucr_loc1line_no_irrelev.append(loc1line_no_irrelev)
            ucr_loc1line.append(loc1line)
            if(isNonLeakError):
                nlel1 = nlel1 + 1
fp.close()

ucrfslen = len(ucr_full_stack) 
ucrloc1len = len(ucr_loc1line)

crash_stats = []

if(ucrfslen != 0):
    with open(prefx+"-crashinfo_unique_stack.txt", "w") as file1:
        file1.writelines(ucr_full_stack)

if(ucrloc1len != 0):
    with open(prefx+"-crashinfo_unique_loc1.txt", "w") as file2:
        file2.writelines(ucr_loc1line)

crash_stats.append(prefx + ": Total number of unique errors based on full stack trace = " + str(ucrfslen) + "\n")
crash_stats.append(prefx + ": Total number of unique errors based on primary error location = " + str(ucrloc1len) + "\n")
crash_stats.append(prefx + ": Number of unique NON-LEAK errors based on full stack trace = " + str(nlefs) + "\n")
crash_stats.append(prefx + ": Number of unique NON-LEAK errors based on primary error location = " + str(nlel1) + "\n")

with open(cfilepdir+"/all-stats.txt", "a") as file3:
    file3.writelines(crash_stats)
