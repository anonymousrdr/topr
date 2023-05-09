import sys

pdir = sys.argv[1]

fp1 = open(pdir+"/mbbls.txt")
mbbls_count = int(fp1.readlines()[0])
fp1.close()

fp = open(pdir+"/vbbls.txt")
vbbls_count = len(fp.readlines())
fp.close()

cov_stat = []
tot_cov = (vbbls_count * 100)/mbbls_count
cov_stat.append(pdir.rsplit('/', 1)[1] + ": Basic block coverage in code pruned w.r.t target = " + str(round(tot_cov,2)) + "%\n")
with open(pdir+"/../all-stats.txt", "a") as file3:
    file3.writelines(cov_stat)
