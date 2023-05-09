#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Analysis/CFG.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/ADT/DepthFirstIterator.h"
#include <unordered_set>
#include <list>
#include <iostream>
#include <fstream>
#include "llvm/IR/Constants.h"
#include "llvm/IR/CFG.h"

using namespace llvm;

namespace {

  struct Tse : public ModulePass { 

	static char ID;

	Tse() : ModulePass(ID) {}

	bool runOnModule(Module &M) override { 
  
		//prevent executing unmarked bbls
		//changing control flow and essentially deleting unmarked bbls and any irrelevant instrs in marked bbls
		
		for(auto &F : M) {

			std::string fnm = std::string(F.getName());

			if(fnm.at(0) == '_') //skip built-in fns
	    	continue;

			//don't unmark bbls of custom pruning fns
			if( (fnm == "bbl_marker") || (fnm == "sc_marker") || (fnm == "prune_exit") || (fnm == "cov_tracker") )
				continue;
			//don't unmark bbls of instrumentation fns
			if( ((fnm.find("llvm")) != std::string::npos) || ((fnm.find("afl")) != std::string::npos) || ((fnm.find("gcov")) != std::string::npos) )
				continue;

			Value* FnRetUndefValue = NULL;
			if(F.getReturnType()->isVoidTy());
			else
				FnRetUndefValue = UndefValue::get(F.getReturnType());

			for(auto &BB: F) {
					
				BasicBlock *bbl = dyn_cast<BasicBlock>(&BB);

				Instruction *termins = bbl->getTerminator();

				if( (dyn_cast<Instruction>(bbl->begin())) == termins ) //terminator is only instruction in bbl
					continue;

				// identifying if and where pruning must start in bbl
				bool toprune = true;
				auto pruneStartIns = BB.begin();
				
				auto ins = BB.begin();
				while(ins != BB.end()) {

					Instruction *inst = dyn_cast<Instruction>(ins);
					++ins; //increment pointer for correct pruning start instr later

					if( (inst!=NULL) && ((inst->getOpcode() == Instruction::Call)) ){

						//handles direct function calls & function pointers to internal functions
						CallInst *callInst = (CallInst*)(inst);
						Value* v=callInst->getCalledOperand();
						Value* sv = v->stripPointerCasts();
						std::string nm = std::string(sv->getName());

						if((nm.compare("bbl_marker")) == 0)
						{
							if(inst == (termins->getPrevNode())) //nothing to prune in bbl
								toprune = false;
							else
								pruneStartIns = ins;
							break;
						}
					}
				}

				// pruning any irrelevant instrs in bbl
				if(toprune)
				{
					Instruction *lins = bbl->getTerminator();

					ins = pruneStartIns;
					while(ins != BB.end()) {

						Instruction *instr = dyn_cast<Instruction>(ins);
						++ins; //increment pointer before deleting instr

						if(instr != lins)
						{
							instr->replaceAllUsesWith(UndefValue::get(instr->getType()));
							instr->eraseFromParent();
						}

						else
						{
							//remove bbl as predecessor from its successors' phi nodes
							for (succ_iterator sit = succ_begin(bbl); sit != succ_end(bbl); ++sit)
							{
								BasicBlock* sbbl = *sit;

								if(sbbl == NULL)
									break;

								for(auto sinsit = sbbl->begin(); sinsit != sbbl->end(); ++sinsit)
								{
									Instruction* sinst = &(*sinsit);

									if(sinst == NULL)
										break;

									if(PHINode *pni = dyn_cast<PHINode>(sinst))
						            {
						            	int pnn = pni->getNumIncomingValues();
						            	for(int pnit = 0; pnit < pnn; pnit++)
						            	{
						            		BasicBlock* pnipbbl = pni->getIncomingBlock(pnit);
						            		if(pnipbbl == bbl)
						            		{
						            			pni->removeIncomingValue(pnit);
						            			break;
						            		}
						            	}
						            }

						            else //stop at 1st non-phi instruction
						            	break;
								}
							}

							//replace bbl terminator with return ins
							IRBuilder<> Builder(lins);
							Value* unret;
							if(FnRetUndefValue == NULL)
								unret = Builder.CreateRetVoid(); // return void
							else
								unret = Builder.CreateRet(FnRetUndefValue); // return undef
							lins->replaceAllUsesWith(unret);
							lins->eraseFromParent();


							//add exit(0) before return so pruned code exits with non-crash termination status
							IRBuilder<> Builder2((Instruction*)unret);
							//std::vector<Value*> args;
							//args.push_back((Value*)ConstantInt::get(Type::getInt32Ty(M.getContext()), 0));
							Function *exitFn = M.getFunction("prune_exit");
							Builder2.CreateCall(cast<FunctionType>(cast<PointerType>(exitFn->getType())->getElementType()), exitFn);//, args);
						}
					}
				}
			}
		}

		return true; //transformation pass - bitcode modified
	}
  };
}

char Tse::ID = 0;
static RegisterPass<Tse> X("tse","Tse",false, false);