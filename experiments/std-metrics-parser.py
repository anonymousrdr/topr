import sys

# standard metrics used in directed fuzzer papers - metric1, metric2

pdir = sys.argv[1]
tool = pdir.rsplit('/', 1)[1]
stdstats = []

# metric1: executions over fuzzing duration
def get_total_execs(filedir):
    texec = 0
    try:
        fp = open(filedir+"/fuzzer_stats")
        lines = fp.readlines()
        fp.close()
        for line in lines:
            if("execs_done" in line):
                texec = int((line.split(":")[1]).strip())
                break
    except:
        pass
    return texec

# metric2: time to 1st bug
# def get_ttb(trialno):
def get_ttb(): # stats of 1st/earliest bug found
    timetb = -1
    bugtyp = ""
    bugloc = ""
    try:
        # fp = open(pdir+"/../"+tool+trialno+"-crashinfo_unique_loc1.txt")
        fp = open(pdir+"/../"+tool+"-crashinfo_unique_loc1.txt")
        lines = fp.readlines()
        fp.close()

        buginp_indx = 0
        bugtyp_indx = 1
        bugloc_indx = 2

        if(lines[bugloc_indx][0] != '#'):
            buginp_indx = 2
            bugtyp_indx = 3
            bugloc_indx = 4
        
        # get bug type
        errline = (lines[bugtyp_indx]).strip()
        bugtyp = (errline.split(":")[2]).strip()
        if(" on " in bugtyp):
            bugtyp = bugtyp[:bugtyp.index(" on")]
        elif(" 0x" in bugtyp):
            bugtyp = bugtyp[:bugtyp.index(" 0x")]

        # get bug location  
        locline = (lines[bugloc_indx]).strip()
        bugloc = (locline.split("/")[-1]).strip()

        # get ttb of bug triggering input
        bugfile = (lines[buginp_indx][7:]).rsplit('/', 1)
        bugfilepath = bugfile[0]
        pdfp = open(pdir+"/../"+tool+"/"+bugfilepath+"/../plot_data")
        pdlines = pdfp.readlines()[1:]
        pdfp.close()
        if("queue" in bugfilepath):
            colno = 3 # col "paths_total"
        elif("crash" in bugfilepath):
            colno = 7 # col "unique_crashes"
        if(len(pdlines) == 0):
            pass
        else:
            timestampfirst = int((pdlines[0]).split(", ")[0])
            bugfilenm = bugfile[1]
            bfilenmid = int(bugfilenm[3:bugfilenm.index(",")])+1
            for pdline in pdlines[1:]:
                pdlinesplits = pdline.split(", ")
                fileid = int(pdlinesplits[colno])
                if(fileid >= bfilenmid):
                    timetb = int(pdlinesplits[0]) - timestampfirst
                    break
    except:
        pass

    stdstats.append(tool + ": Time to bug (sec) = " + str(timetb) + "\n")
    stdstats.append(tool + ": Bug type = " + bugtyp + " AND Bug loc = " + bugloc + "\n")



if(len(sys.argv)>2): # topr+aflgo vs. sievefuzz - 1 core fuzzing
    inpdir = pdir+"/out/"+sys.argv[2]
    total_execs = get_total_execs(inpdir)
else: # topr+aflgo vs. aflgo - 22 core parallel fuzzing
    inpdir = pdir+"/out"
    execs_list = []
    for i in range(22):
        inpdir1 = inpdir + "/fuz" + str(i)
        execs_list.append(get_total_execs(inpdir1))
    total_execs = sum(execs_list)

stdstats.append(tool + ": Total fuzzing executions = " + str(total_execs) + "\n")
# get_ttb(trialno)
get_ttb()

with open(pdir+"/../all-stats.txt", "a") as fileO:
    fileO.writelines(stdstats)
