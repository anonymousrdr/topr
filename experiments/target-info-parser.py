import sys

pdir = sys.argv[1]

# no. of inputs reaching target line, no. of times it reaches
targ_stats = []
tool = pdir.rsplit('/', 1)[1]
ip_reach = set()

fp = open(pdir+"/targstats.txt", errors="ignore")
lines = fp.readlines()
indx = 0
line_count = len(lines)
num_targ_reached_all_ips = 0
while(indx < line_count):
    line = lines[indx]
    line = line.strip()
    indx = indx + 1
    if(line == ''):
        continue
    if("INPUT: " in line):
        num_targ_reached_this_ip = 0
        inpnm = (line.split(" ")[1]) + "\n"
        while(indx < line_count):
            line = lines[indx]
            line = line.strip()
            indx = indx + 1
            if(len(line)==0):
                continue
            if("END OF REPLAY----" == line):
                break
            if("REACHED TARGET: " in line):
                num_targ_reached_this_ip = int(line[16:])
        if(num_targ_reached_this_ip != 0):
            num_targ_reached_all_ips = num_targ_reached_all_ips + num_targ_reached_this_ip
            ip_reach.add(inpnm)
fp.close()

inpslist = list(ip_reach)
num_ips_targ = len(inpslist)

targ_stats.append(tool + ": Total number of inputs that reach target = " + str(num_ips_targ) + "\n")
targ_stats.append(tool + ": Total number of times all inputs reach target = " + str(num_targ_reached_all_ips) + "\n")

with open(pdir+"/../all-stats.txt", "a") as file3:
    file3.writelines(targ_stats)

if(num_ips_targ != 0):
    with open(pdir+"/../targ-ips.txt", "w") as file4:
        file4.writelines(inpslist)
