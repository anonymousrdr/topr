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
#include <string>
#include <regex>

using namespace llvm;

namespace {

  struct Btrace : public ModulePass { 

    static char ID;

    Btrace() : ModulePass(ID) {}

	Function* bblMarkerFn;
	std::set<Instruction*> targetSet;
	Instruction* instsc = NULL; //current target
  std::map<std::string, std::vector<std::pair<std::string, Instruction*>>> callgraph; //note: callee nodes are unique/distinct even for same fn name due to instruction ptrs
  std::set<BasicBlock*> marked_bbls;
	int mbblid = 0; //to distinguish marked bbls during execution
	std::set<std::string> fullfns;
	std::set<std::string> fullfnsigs;
	// int num_indirect_fncalls_cg = 0; //num of indirect fn calls counted when constructing callgraph
	// int num_indirect_fncalls_targ = 0; //num of indirect fn calls counted when marking relevant bbls wrt targets

	std::string extractUniqueType(std::string typestr)
  {
  	// remove SUFFIX digits only immediately following '.', don't remove digits appearing elsewhere
  		// eg: struct.test.10.20 -> struct.test
    std::string parsedstr = typestr;
    while(parsedstr.length() != 0)
    {
      auto pos = parsedstr.rfind('.'); // go from right to left
      if(pos != std::string::npos)
      {
        std::string latterstr;
        latterstr = parsedstr.substr(pos+1);
        std::string::const_iterator it = latterstr.begin();
        std::string digitstring = "";
        while(it != latterstr.end() && std::isdigit(*it))
        {
          digitstring = digitstring + (*it);
          ++it;
        }
        if(digitstring == "")  // no digits immediately following '.' => no need to continue left
          break;
        else
        {
          if(it != latterstr.end() && std::isalpha(*it)); // don't remove digits followed by alphabets
          else
            parsedstr = std::regex_replace(parsedstr, std::regex("."+digitstring), "");
        }
      }
      else // no '.'
        break;
    }
    return parsedstr;
  }
    
	void findTargets(Module &M)
	{
		for(auto &F : M) {
			for(auto &BB : F) {
				auto ins = BB.begin();
				while(ins != BB.end()) {
					Instruction *inst = dyn_cast<Instruction>(ins);
					++ins;

					if(inst->getOpcode() == Instruction::Call){

						//handles direct function calls & function pointers to internal functions
						CallInst *callInst = (CallInst*)(inst);
						std::string nm="";
						auto calldF = dyn_cast<Function>(callInst->getCalledOperand()->stripPointerCasts());
						if (calldF)
							nm = std::string(calldF->getName());
						else
							continue;
						 
				 		if((nm.compare("sc_marker")) == 0)
				 			targetSet.insert(inst);
		   		}
		  	}
	 		}
    }
	}

	void callGraphConstruct(Module &M)
  {
  	//construct entire callgraph for efficient bottom up (starting from target to entry fn) marking of paths to target --> key: fn, value: list of fn callers

		//handle function pointers using fn signature matching 
			//all possible fns are considered - no dataflow analysis to track the static values of fn ptr variables

		for(auto &F : M) {

  	std::string curFnNm = std::string(F.getName());

  	if( (curFnNm == "bbl_marker") || (curFnNm == "sc_marker") || (curFnNm == "prune_exit") || (curFnNm == "cov_tracker") ) //ignore custom pruning fns
			  continue;

		std::string curFnSig = "";
		for(auto argit = F.arg_begin(); argit != F.arg_end(); ++argit)
		{
			std::string emt = "";
			raw_string_ostream rso(emt);
			(argit->getType())->print(rso);
			std::string femt = rso.str();
			std::string pfemt = extractUniqueType(femt);
			curFnSig = curFnSig + pfemt + ", ";
		}
		std::string emt = "";
		raw_string_ostream rso(emt);
		(F.getReturnType())->print(rso); //return type of function
		std::string femt = rso.str();
		std::string pfemt = extractUniqueType(femt);
		curFnSig = curFnSig + pfemt;

			for(auto &BB : F) {
				auto ins = BB.begin();
				while(ins != BB.end()) {
					Instruction *binst = dyn_cast<Instruction>(ins);
					++ins;

					if( (binst->getOpcode() == Instruction::Call) || (binst->getOpcode() == Instruction::Invoke) )
					{
						//handles direct function calls & function pointers to internal functions
						std::string bnm="";
						if(CallInst *bcallInst = (CallInst*)(binst))
						{
							auto calldF = dyn_cast<Function>(bcallInst->getCalledOperand()->stripPointerCasts());
							if (calldF)
								bnm = std::string(calldF->getName());
						}
						else if(InvokeInst *binvInst = (InvokeInst*)binst)
						{
							auto calldF = dyn_cast<Function>(binvInst->getCalledOperand()->stripPointerCasts());
							if (calldF)
								bnm = std::string(calldF->getName());
						}

						if(bnm != "")
						{
							if( (bnm != "bbl_marker") && (bnm != "sc_marker") && (bnm != "prune_exit") && (bnm != "cov_tracker") && ((bnm.find("llvm.") == std::string::npos)) ) //ignore custom pruning, llvm fns
								callgraph[bnm].push_back(std::make_pair(curFnNm, binst));
						}

						else //handle indirect fn calls w/ fn pointers where fn names can't be extracted
						{
							// num_indirect_fncalls_cg++;
							
							std::string fsig = "";

							//get fn signature
							for(auto fop = binst->op_begin(); fop != (binst->op_end())-1; ++fop)
							{
								std::string emt = "";
								raw_string_ostream rso(emt);
								((*fop)->getType())->print(rso);
								std::string femt = rso.str();
								std::string pfemt = extractUniqueType(femt);
								fsig = fsig + pfemt + ", ";
							}
							std::string emt = "";
							raw_string_ostream rso(emt);
							(binst->getType())->print(rso); //return type of function = type of call instr
							std::string femt = rso.str();
							std::string pfemt = extractUniqueType(femt);
							fsig = fsig + pfemt;  
							
							for(auto &F1 : M) {
						  	std::string curFnNm1 = std::string(F1.getName());
						  	if( (curFnNm1 == "bbl_marker") || (curFnNm1 == "sc_marker") || (curFnNm1 == "prune_exit") || (curFnNm1 == "cov_tracker") ) //ignore custom pruning fns
						  		continue;

								std::string curFnSig1 = "";
								for(auto argit1 = F1.arg_begin(); argit1 != F1.arg_end(); ++argit1)
								{
									std::string emt1 = "";
									raw_string_ostream rso1(emt1);
									(argit1->getType())->print(rso1);
									curFnSig1 = curFnSig1 + rso1.str() + ", ";
								}
								std::string emt1 = "";
								raw_string_ostream rso1(emt1);
								(F1.getReturnType())->print(rso1); //return type of function
								curFnSig1 = curFnSig1 + rso1.str();

								if(curFnSig1 == fsig)
									callgraph[curFnNm1].push_back(std::make_pair(curFnNm, binst));
							}
						}
					}
				}
			}
		}
	}
	
	void markBBLs(Module &M, Instruction *callerInst) // fn for marking part of bbl upto a given fn. call
	{
		BasicBlock* bbl1 = callerInst->getParent();

		//inverse DFS - walking over predecessors of a bbl in its function alone
		//note: bbl itself is also visited along with preds during idfs
		for (idf_iterator<BasicBlock*> I=idf_begin(bbl1); I!=idf_end(bbl1);++I)
		{
			BasicBlock* bbl = *I;

			//go through fns in bbl n track fns before callerInst to be marked
			//note: this must be done atleast once for every new callerInst even if bbl is already marked to correctly handle case with multiple calls to same fn - each call instr is unique and is used to differentiate such calls
			auto bblit = bbl->begin();
			Instruction *binst = NULL;
			while(bblit != bbl->end())
			{
				Instruction &bbinst = *bblit;
				++bblit;
				binst = dyn_cast<Instruction>(&bbinst);
				
				if(binst == callerInst) //hard stop at target call instr in fn - required bbls in nxt path fn will be marked during path traversal
				  break; 
			   
				if( (binst->getOpcode() == Instruction::Call) || (binst->getOpcode() == Instruction::Invoke) )
				{
					//handles direct function calls & function pointers to internal functions
					std::string bnm="";
					if(CallInst *bcallInst = (CallInst*)(binst))
					{
						auto calldF = dyn_cast<Function>(bcallInst->getCalledOperand()->stripPointerCasts());
						if (calldF)
							bnm = std::string(calldF->getName());
					}
					else if(InvokeInst *binvInst = (InvokeInst*)binst)
					{
						auto calldF = dyn_cast<Function>(binvInst->getCalledOperand()->stripPointerCasts());
						if (calldF)
							bnm = std::string(calldF->getName());
					}

					if(bnm != "")
						fullfns.insert(bnm);

					else //handle indirect fn calls w/ fn pointers where fn names can't be extracted
					{
						// num_indirect_fncalls_targ++;
						// errs()<<"Indirect function call site resolved by TOPr: "<<*binst<<"\n";

						std::string fsig = "";

						//get fn signature
						for(auto fop = binst->op_begin(); fop != (binst->op_end())-1; ++fop)
						{
							std::string emt = "";
							raw_string_ostream rso(emt);
							((*fop)->getType())->print(rso);
							std::string femt = rso.str();
							std::string pfemt = extractUniqueType(femt);
							fsig = fsig + pfemt + ", ";
						}
						std::string emt = "";
						raw_string_ostream rso(emt);
						(binst->getType())->print(rso); //return type of function = type of call instr
						std::string femt = rso.str();
						std::string pfemt = extractUniqueType(femt);
						fsig = fsig + pfemt;  
						
						fullfnsigs.insert(fsig);
					}

				}
			}

			bool insertMarker = true;
			Instruction *mbefore = binst->getNextNode();

			//mark bbl just once
			if(marked_bbls.find(bbl) != marked_bbls.end()) //bbl already marked
			{	
				//correctly handles case with multiple calls to same fn - each call instr is unique and is used to differentiate such calls
				//include more instrs in bbl if required
   			auto insUp = bbl->begin();
				while(insUp != bbl->end()) 
				{
					Instruction *instUp = dyn_cast<Instruction>(insUp);
					if(instUp == mbefore) //reached binst->getNextNode() w/o finding bbl marker means bbl marker is after binst instr so leave as is
					{
						insertMarker = false;
						break;
					}
					//remove bbl marker if it occurs before binst instr
					++insUp; //increment pointer deleting instr
					if( (instUp!=NULL) && ((instUp->getOpcode() == Instruction::Call)) )
					{
						//handles direct function calls & function pointers to internal functions
       			CallInst *tpicallInst = (CallInst*)(instUp);
						Value* tpiv = tpicallInst->getCalledOperand();
						Value* tpisv = tpiv->stripPointerCasts();
						std::string tpinm = std::string(tpisv->getName());
						if((tpinm.compare("bbl_marker")) == 0)
       			{
							instUp->replaceAllUsesWith(UndefValue::get(instUp->getType()));
							instUp->eraseFromParent();
							break;
						}
					}
				}
			}
			else
				marked_bbls.insert(bbl);

			//insert new bbl marker further down in bbl
			if(insertMarker)
			{
				mbblid++;
				//insert special marker function immediately after call instr in bbl or before bbl terminator instr in other bbls
				//so that all irrelevant fn calls are also be pruned else undef return values will cause pruned code to crash
				if(mbefore == NULL) //no next instr means binst is bbl terminator instr
					mbefore = binst;
				IRBuilder<> Builder(mbefore);
				std::vector<Value*> args;
				args.push_back((Value*)ConstantInt::get(Type::getInt32Ty(M.getContext()), mbblid));
				Builder.CreateCall(cast<FunctionType>(cast<PointerType>(bblMarkerFn->getType())->getElementType()), bblMarkerFn, args);
			}
		}
	}

	void markPathsToTargetFn(Module &M)
	{
		//path marking starting from target function to entry fns in call graph - for speed uses set datastructure without tracking traversal order

		/*
		//print call graph
		errs()<<"\n\n\n------Start of Callgraph--------\n\n\n";
		std::map<std::string, std::vector<std::pair<std::string, Instruction*>>>::iterator mit = callgraph.begin();
    while (mit != callgraph.end())
    {
      std::string FnNm = mit->first;
      mit++;
      errs()<<FnNm<<"-->";
      std::vector<std::pair<std::string, Instruction*>> callerList = callgraph[FnNm];
      for(long vi = 0; vi < callerList.size(); vi++)
      {
        std::pair<std::string, Instruction*> callerFn = callerList[vi];
        std::string callerFnNm = callerFn.first;
        errs()<<callerFnNm<<", ";
      }
      errs()<<"\n";
    }
    errs()<<"\n\n------End of Callgraph--------\n\n\n";
    */

		std::set<std::string> pathFnSet;
		pathFnSet.insert(std::string(instsc->getParent()->getParent()->getName())); //target function
		std::set<std::string> visitedFnSet;

		while(pathFnSet.size() != 0)
		{
			auto setIterator = pathFnSet.begin();
			std::string pathFnNm = *setIterator;
			pathFnSet.erase(setIterator);

			if((visitedFnSet.find(pathFnNm)) != visitedFnSet.end()) //already visited fn and marked all paths TO this fn so skip
				continue;

      std::vector<std::pair<std::string, Instruction*>> callerList = callgraph[pathFnNm];
      int clsz = callerList.size();
      //errs()<<pathFnNm<<": "<<clsz<<"\n";
      for(long vi = 0; vi < clsz; vi++)
      {
        std::pair<std::string, Instruction*> callerFn = callerList[vi];
        std::string callerFnNm = callerFn.first;

        pathFnSet.insert(callerFnNm); //traversal order is irrelevant
       	
        //note: this must be done atleast once for every new callerInst even if bbls in  Fn are already marked to correctly handle case with multiple calls to same fn - each call instr is unique and is used to differentiate such calls
       	Function *pfn = M.getFunction(callerFnNm);
				if(pfn == NULL) //empty fn body
					continue;

       	Function& Fn = *pfn;
				bool doneMark = false;

				for(auto &BB : Fn) {

					if(doneMark)
						break;

					for(auto &ins : BB) {

					  Instruction* callerInst = dyn_cast<Instruction>(&ins);
				
						//next Fn in path
					    //also correctly handles case with multiple calls to same fn - each call instr is unique and is used to differentiate such calls
						if(callerInst != callerFn.second)
							continue;

						markBBLs(M, callerInst);
		        doneMark = true;
		        break;
		    	}
				}
      }

      visitedFnSet.insert(pathFnNm);

  	}
	}

	void markFullFns(Module &M)
	{
		//traverse all fns in module and add to fullfns if fn signatures match any in set fullfnsigs - corresponding to fn pointers
		for(auto &F : M) 
		{
			std::string fsig = "";
			for(auto argit = F.arg_begin(); argit != F.arg_end(); ++argit)
			{
				std::string emt = "";
				raw_string_ostream rso(emt);
				(argit->getType())->print(rso);
				std::string femt = rso.str();
				std::string pfemt = extractUniqueType(femt);
				fsig = fsig + pfemt + ", ";
			}
			std::string emt = "";
			raw_string_ostream rso(emt);
			(F.getReturnType())->print(rso); //return type of function
			std::string femt = rso.str();
			std::string pfemt = extractUniqueType(femt);
			fsig = fsig + pfemt; 

			if(fullfnsigs.find(fsig) != fullfnsigs.end())
				fullfns.insert(std::string(F.getName()));
		}

	  //mark all bbls in fullfns
		std::set<std::string> visitedFullfns;
		while(fullfns.size() != 0)
		{
			auto ritr = fullfns.begin();
			std::string rfn = *ritr;
			fullfns.erase(ritr);

			if((visitedFullfns.find(rfn)) != visitedFullfns.end()) //already visited fn and marked so skip
				continue;
				
			if( (rfn == "bbl_marker") || (rfn == "sc_marker") || (rfn == "prune_exit") || (rfn == "cov_tracker") ) //don't mark bbls of custom pruning fns
				continue;

			Function *rf = M.getFunction(rfn);
			if(rf == NULL) //empty fn body
				continue;

			for(auto rbitr = rf->begin(); rbitr != rf->end(); ++rbitr) 
			{
			  BasicBlock &rBB = *rbitr;
			  BasicBlock *bbl = dyn_cast<BasicBlock>(&rBB);
			   	      	      
			  //mark bbl just once
			  if(marked_bbls.find(bbl) != marked_bbls.end()) //bbl already marked
        {
       		//ensure marking full bbl
      		//remove current bbl marker
     			auto insUp = bbl->begin();
					while(insUp != bbl->end()) 
					{
						Instruction *instUp = dyn_cast<Instruction>(insUp);
						++insUp; //increment pointer deleting instr
						if( (instUp!=NULL) && ((instUp->getOpcode() == Instruction::Call)) )
						{
							//handles direct function calls & function pointers to internal functions
         			CallInst *tpicallInst = (CallInst*)(instUp);
							Value* tpiv = tpicallInst->getCalledOperand();
							Value* tpisv = tpiv->stripPointerCasts();
							std::string tpinm = std::string(tpisv->getName());
							if((tpinm.compare("bbl_marker")) == 0)
         			{
								instUp->replaceAllUsesWith(UndefValue::get(instUp->getType()));
								instUp->eraseFromParent();
								break;
							}
						}
					}
       	}
		    else 
		    	marked_bbls.insert(bbl);

		    //insert bbl marker at end of bbl
			  mbblid++;
				Instruction *lins = bbl->getTerminator(); //last instr in bbl
				//insert special marker function before last instr in bbl
				IRBuilder<> Builder(lins);
				std::vector<Value*> args;
				args.push_back((Value*)ConstantInt::get(Type::getInt32Ty(M.getContext()), mbblid));
				Builder.CreateCall(cast<FunctionType>(cast<PointerType>(bblMarkerFn->getType())->getElementType()), bblMarkerFn, args);

			  //mark full bbl - go through fns in bbls n track fns to be marked
			  for(auto bblit = bbl->begin(); bblit != bbl->end(); ++bblit){
			    Instruction &bbinst = *bblit;
			    Instruction *binst = dyn_cast<Instruction>(&bbinst);
			    if( (binst->getOpcode() == Instruction::Call) || (binst->getOpcode() == Instruction::Invoke) )
			    {
						//handles direct function calls & function pointers to internal functions
						std::string bnm="";
						if(CallInst *bcallInst = (CallInst*)(binst))
						{
							auto calldF = dyn_cast<Function>(bcallInst->getCalledOperand()->stripPointerCasts());
							if (calldF)
								bnm = std::string(calldF->getName());
						}
						else if(InvokeInst *binvInst = (InvokeInst*)binst)
						{
							auto calldF = dyn_cast<Function>(binvInst->getCalledOperand()->stripPointerCasts());
							if (calldF)
								bnm = std::string(calldF->getName());
						}

						if(bnm != "")
							fullfns.insert(bnm);

						else //handle indirect fn calls w/ fn pointers where fn names can't be extracted
						{
							// num_indirect_fncalls_targ++;
							// errs()<<"Indirect function call site resolved by TOPr: "<<*binst<<"\n";

							std::string fsig = "";
							
							//get fn signature
							for(auto fop = binst->op_begin(); fop != (binst->op_end())-1; ++fop)
							{
								std::string emt = "";
								raw_string_ostream rso(emt);
								((*fop)->getType())->print(rso);
								std::string femt = rso.str();
								std::string pfemt = extractUniqueType(femt);
								fsig = fsig + pfemt + ", ";
							}
							std::string emt = "";
							raw_string_ostream rso(emt);
							(binst->getType())->print(rso); //return type of function = type of call instr
							std::string femt = rso.str();
							std::string pfemt = extractUniqueType(femt);
							fsig = fsig + pfemt; 

							if(fullfnsigs.find(fsig) != fullfnsigs.end()); //if fn signature already in fsigs then fn name already inserted into fullfns
							
							else
							{
								//traverse all fns in module and add to fullfns if fn signatures match any in set fullfnsigs - corresponding to fn pointers
								for(auto &F : M) 
								{
									std::string fsig2 = "";
									for(auto argit = F.arg_begin(); argit != F.arg_end(); ++argit)
									{
										std::string emt = "";
										raw_string_ostream rso(emt);
										(argit->getType())->print(rso);
										std::string femt = rso.str();
										std::string pfemt = extractUniqueType(femt);
										fsig2 = fsig2 + pfemt + ", ";
									}
									std::string emt = "";
									raw_string_ostream rso(emt);
									(F.getReturnType())->print(rso); //return type of function
									std::string femt = rso.str();
									std::string pfemt = extractUniqueType(femt);
									fsig2 = fsig2 + pfemt; 

									if((fsig.compare(fsig2)) == 0)
										fullfns.insert(std::string(F.getName()));
								}
							}
						}
			 		}
			  }
			}
			visitedFullfns.insert(rfn);
		}
	}


    bool runOnModule(Module &M) override 
    {
	    //bblMarkerFn = M.getOrInsertFunction("bbl_marker", Type::getVoidTy(M.getContext()), Type::getInt32Ty(M.getContext()));
	    bblMarkerFn = M.getFunction("bbl_marker");

	    if(bblMarkerFn == NULL) //empty fn body
			{
	    	errs()<<"ERROR: MARKER FUNCTION NOT FOUND\n";
	    	return false;
	    }
	    	
			findTargets(M); //supports multiple targets

	    if(targetSet.size() == 0)
	    {
	    	errs()<<"ERROR: NO TARGET FOUND\n";
	    	return false;
	    }

			//trace paths to target
		    //note: llvm callgraph does not handle function pointers - eg: toy code
			//so construct callgraph manually - fn signature matching to handle function pointers
					//mark only bbls upto target instr in its fn
					//fns in paths - mark bbls only upto next fn in path
					//fullfns - mark entire fn - correspond to fn calls either before target instr or before next fn in path
			
			callGraphConstruct(M);
			errs()<<"Callgraph constructed.\n";
			
			//go through every target
			while(targetSet.size() != 0)
			{
				auto tsetIterator = targetSet.begin();
				instsc = *tsetIterator;
				targetSet.erase(tsetIterator);

				markBBLs(M, instsc); //mark BBLs in target fn
				errs()<<"Target function BBLs marked.\n";
				markPathsToTargetFn(M);
				errs()<<"Path function BBLs marked.\n";
			}

			//mark built-in fns and child fns
			for(auto &F : M) 
			{
				std::string fnm = std::string(F.getName());
				if(fnm.at(0) == '_')
		    	fullfns.insert(fnm);
	  	}
	  	//mark init fns - supports multithreading
  	  std::ifstream extraceFile;
      extraceFile.open("initfns.txt");
      if(!extraceFile);
      else
      {
        std::string line = "";
        while(std::getline(extraceFile, line))
          fullfns.insert(line);
      }
      extraceFile.close();
			markFullFns(M);
			errs()<<"Other required path functions marked.\n";
			
			std::ofstream mfile;
			mfile.open ("mbbls.txt");
			mfile <<marked_bbls.size()<<"\n";
			mfile.close();

			// num of indirect fn calls counted when constructing callgraph
			// errs()<<"Num. indirect function calls resolved statically by TOPr while constructing call graph = "<<num_indirect_fncalls_cg<<"\n";
			// num of indirect fn calls counted when marking relevant bbls wrt targets
			// errs()<<"Num. indirect function calls resolved statically by TOPr when marking BBLs wrt targets = "<<num_indirect_fncalls_targ<<"\n";

			return true; //transformation pass - bitcode modified
    }
  };
}

char Btrace::ID = 0;
static RegisterPass<Btrace> X("btrace","Btrace",false, false);