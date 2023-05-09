#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Analysis/CFG.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/ADT/DepthFirstIterator.h"
#include <set>
#include <list>
#include <iostream>
#include <fstream>
#include "llvm/IR/Constants.h"
#include <algorithm>
#include "llvm/IR/CFG.h"

using namespace llvm;

namespace {

  struct Btrace : public ModulePass { 

    static char ID;

    Btrace() : ModulePass(ID) {}

    bool runOnModule(Module &M) override 
    {
	    Function *covTrackerFn = M.getFunction("cov_tracker");
	    int bblid = 0;
	    for(auto &F : M) {
	   
	    	std::string fnm = std::string(F.getName());
	    	
	    	if(fnm.at(0) == '_') //skip built-in fns
	    		continue;

				//skip custom pruning fns
				if( (fnm == "bbl_marker") || (fnm == "sc_marker") || (fnm == "prune_exit") || (fnm == "cov_tracker") )
					continue;
				
				for(auto &BB : F) {
					BasicBlock *bbl = dyn_cast<BasicBlock>(&BB);
			    bblid++;
			    Instruction *mbefore = &(*(bbl->getFirstInsertionPt()));
			    IRBuilder<> Builder(mbefore);
					std::vector<Value*> args;
					args.push_back((Value*)ConstantInt::get(Type::getInt32Ty(M.getContext()), bblid));
					Builder.CreateCall(cast<FunctionType>(cast<PointerType>(covTrackerFn->getType())->getElementType()), covTrackerFn, args);
				}
			}

			return true; //transformation pass - bitcode modified
    }
  };
}

char Btrace::ID = 0;
static RegisterPass<Btrace> X("btrace","Btrace",false, false);