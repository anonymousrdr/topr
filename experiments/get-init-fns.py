#extract init fns from running instrumented exe on 1 input

callee_set = set()
initfns_set = set()

fp = open("tracecall.txt")
lines = fp.readlines()
for line in lines:
  line = line.strip()
  if(line == ''):
    continue
  line_contents = line.split("===>")
  caller = line_contents[0].strip()
  if(caller not in callee_set):
    initfns_set.add(caller+'\n')
  callee_set.add(line_contents[1].strip())
fp.close()

if("main\n" in initfns_set):
  initfns_set.remove("main\n") #don't mark 'main' full fn

with open("initfns.txt", "w") as file:
  file.writelines(list(initfns_set))
