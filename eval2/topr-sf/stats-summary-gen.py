import sys

def get_mn(valslist): # get arithmetic mean over 10 trials
    mn = str(sum(valslist)/10)
    return mn

def get_mn_ttb(valslist): # get arithmetic mean over trials with non-zero values
    mn = str(sum(valslist)/len(valslist))
    return mn

all_stats_file = sys.argv[1]
all_stats_file_path = all_stats_file.rsplit('/',1)[0]

# topr+aflgo stats
toprgo_total_ips_reach_targ = []
toprgo_total_times_reach_targ = []
toprgo_total_errs_fs = []
toprgo_total_errs_loc1 = []
toprgo_cov = []
toprgo_texec = []
toprgo_ttb = []
toprgo_bugtyploc = dict()

# sievefuzz stats
sf_total_ips_reach_targ = []
sf_total_times_reach_targ = []
sf_total_errs_fs = []
sf_total_errs_loc1 = []
sf_cov = []
sf_texec = []
sf_ttb = []
sf_bugtyploc = dict()

fp = open(all_stats_file)
lines = fp.readlines()
fp.close()
for line in lines:
    line = line.strip()
    if(line == ''):
        continue

    if("Bug type" in line): # bug types and locations whose set to be computed
        bty = (line[line.index("type =")+6:line.index(" AND")]).strip()
        bgloc = (line[line.index("loc =")+5:]).strip()
        if("aflgo-prune" in line):
            toprgo_bugtyploc[bty] = bgloc
        else:
            sf_bugtyploc[bty] = bgloc

    else: # values whose mean to be computed
        valstr = line.split(" ")[-1]
        if("%" in valstr):
            val = float(valstr[:-1])
        else:
            val = int(valstr)
        if(val > 0):
            if("Total number of inputs that reach target" in line):
                if("aflgo-prune" in line):
                    toprgo_total_ips_reach_targ.append(val)
                else:
                    sf_total_ips_reach_targ.append(val)
            elif("Total number of times all inputs reach target" in line):
                if("aflgo-prune" in line):
                    toprgo_total_times_reach_targ.append(val)
                else:
                    sf_total_times_reach_targ.append(val)
            elif("Total number of unique errors based on full stack trace" in line):
                if("aflgo-prune" in line):
                    toprgo_total_errs_fs.append(val)
                else:
                    sf_total_errs_fs.append(val)
            elif("Total number of unique errors based on primary error location" in line):
                if("aflgo-prune" in line):
                    toprgo_total_errs_loc1.append(val)
                else:
                    sf_total_errs_loc1.append(val)
            elif("Basic block coverage in code pruned w.r.t target" in line):
                if("aflgo-prune" in line):
                    toprgo_cov.append(val)
                else:
                    sf_cov.append(val)
            elif("Total fuzzing executions" in line):
                if("aflgo-prune" in line):
                    toprgo_texec.append(val)
                else:
                    sf_texec.append(val)
            elif("Time to bug" in line):
                if("aflgo-prune" in line):
                    toprgo_ttb.append(val)
                else:
                    sf_ttb.append(val)

sum_stats = []

sum_stats.append("Arithmetic mean of metrics over 10 trials:\n")
sum_stats.append("aflgo-prune: unique errors based on full stack trace = " + get_mn(toprgo_total_errs_fs) + "\n")
sum_stats.append("aflgo-prune: unique errors based on primary error location = " + get_mn(toprgo_total_errs_loc1) + "\n")
sum_stats.append("aflgo-prune: number of inputs that reach target = " + get_mn(toprgo_total_ips_reach_targ) + "\n")
sum_stats.append("aflgo-prune: number of times target reached = " + get_mn(toprgo_total_times_reach_targ) + "\n")
sum_stats.append("aflgo-prune: basic block coverage w.r.t target = " + get_mn(toprgo_cov) + "%\n")
sum_stats.append("aflgo-prune: executions = " + get_mn(toprgo_texec) + "\n")
if(len(toprgo_total_errs_fs) == 0):
    sum_stats.append("aflgo-prune: time to bug = -1\n")
else:
    sum_stats.append("aflgo-prune: time to bug = " + get_mn_ttb(toprgo_ttb) + "\n")
sum_stats.append("aflgo-prune: bug types and locs = " + str(toprgo_bugtyploc) + "\n")

sum_stats.append("sievefuzz: unique errors based on full stack trace = " + get_mn(sf_total_errs_fs) + "\n")
sum_stats.append("sievefuzz: unique errors based on primary error location = " + get_mn(sf_total_errs_loc1) + "\n")
sum_stats.append("sievefuzz: number of inputs that reach target = " + get_mn(sf_total_ips_reach_targ) + "\n")
sum_stats.append("sievefuzz: number of times target reached = " + get_mn(sf_total_times_reach_targ) + "\n")
sum_stats.append("sievefuzz: basic block coverage w.r.t target = " + get_mn(sf_cov) + "%\n")
sum_stats.append("sievefuzz: executions = " + get_mn(sf_texec) + "\n")
if(len(sf_total_errs_fs) == 0):
    sum_stats.append("sievefuzz: time to bug = -1\n")
else:
    sum_stats.append("sievefuzz: time to bug = " + get_mn_ttb(sf_ttb) + "\n")
sum_stats.append("sievefuzz: bug types and locs = " + str(sf_bugtyploc) + "\n")

with open(all_stats_file_path+"/sum-stats.txt", "w") as file2:
    file2.writelines(sum_stats)
