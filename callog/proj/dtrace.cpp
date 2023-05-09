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

  struct Dtrace : public ModulePass { 

    static char ID;

    Dtrace() : ModulePass(ID) {}

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

    bool runOnModule(Module &M) override {

      //traverse all fns in module and extract fn signatures
      std::map<std::string, std::vector<std::string>> fnsigns; //key: fn signature, values: fn names
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

        fnsigns[fsig].push_back(std::string(F.getName()));
      }

      Function* loggerfn = M.getFunction("loggerfn");

      for(auto &F : M) {
        Function *ofn = dyn_cast<Function>(&F);
        std::string fnname = std::string(ofn->stripPointerCasts()->getName());
        
        //skip custom fns
        if((fnname == "loggerfn") || (fnname == "bbl_marker") || (fnname == "sc_marker") || (fnname == "prune_exit"))
          continue;

        for(auto &BB : F) {
          for(auto &I : BB){

            Instruction *inst = dyn_cast<Instruction>(&I);
            if( (inst->getOpcode() == Instruction::Call) || (inst->getOpcode() == Instruction::Invoke) )
            {  
              CallInst *callInst = (CallInst*)(inst);
              if(callInst != NULL) //skip call to custom fns
              {
                std::string calleefnnm = std::string(callInst->getCalledOperand()->stripPointerCasts()->getName());
                
                if((calleefnnm == "loggerfn") || (calleefnnm == "bbl_marker") || (calleefnnm == "sc_marker") || (calleefnnm == "prune_exit")) 
                  continue;

                //insert after call instruction => before instruction after call - IRBuilder.h
                IRBuilder<> Builder(inst);

                /*std::string callins = "";
                raw_string_ostream rso(callins);
                inst->print(rso);*/

                Value *strConstant  = Builder.CreateGlobalString(StringRef(fnname),"fnname");
                Value* strCaller = new BitCastInst(strConstant, Type::getInt8PtrTy(M.getContext()), "typecast", inst);
                
                if(calleefnnm != "")
                {
                  Value *strConstant2  = Builder.CreateGlobalString(StringRef(calleefnnm),"calleefnnm");
                  Value* strCallee = new BitCastInst(strConstant2, Type::getInt8PtrTy(M.getContext()), "typecast", inst);
                  std::vector<Value*> args;
                  args.push_back(strCaller);
                  args.push_back(strCallee);
                  Builder.CreateCall(loggerfn, args);
                }
                else //handle indirect fn calls w/ fn pointers where fn names can't be extracted
                {
                  std::string fsig = "";

                  //get fn signature
                  for(auto fop = inst->op_begin(); fop != (inst->op_end())-1; ++fop)
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
                  (inst->getType())->print(rso); //return type of function = type of call instr
                  std::string femt = rso.str();
                  std::string pfemt = extractUniqueType(femt);
                  fsig = fsig + pfemt;

                  std::vector<std::string> fnList = fnsigns[fsig];
                  int clsz = fnList.size();
                  for(long vi = 0; vi < clsz; vi++) //for each fn name matching fn signature, create log
                  {
                    calleefnnm = fnList[vi];
                    Value *strConstant2  = Builder.CreateGlobalString(StringRef(calleefnnm),"calleefnnm");
                    Value* strCallee = new BitCastInst(strConstant2, Type::getInt8PtrTy(M.getContext()), "typecast", inst);
                    std::vector<Value*> args;
                    args.push_back(strCaller);
                    args.push_back(strCallee);
                    Builder.CreateCall(loggerfn, args);
                  }
                }
              }
            }
          }
        }
      }
      return true; //transformation pass - bitcode modified
    }
  };
}

char Dtrace::ID = 0;
static RegisterPass<Dtrace> X("dtrace","Dtrace",false, false);