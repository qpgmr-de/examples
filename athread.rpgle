**free
ctl-opt main(main) dftactgrp(*no) actgrp('ATHREAD');
ctl-opt datedit(*dmy/) option(*srcstmt:*nodebugio);

/copy qsysinc/qrpglesrc,pthread        // PThread prototypes
/copy qsysinc/qrpglesrc,unistd         // misc prototypes (e.g. sleep)

// template for worker parameters
dcl-ds worker_parm_t qualified template;
  num int(10:0);
  delay int(10:0);
end-ds;

//------------------------------------------------------------------------------
// main procedure
//------------------------------------------------------------------------------
dcl-proc Main;

  dcl-ds workers dim(4) qualified inz;
    thread likeds(pthread_t);
    parm likeds(worker_parm_t);
  end-ds;

  dcl-s isAbnormalEnd ind inz;
  dcl-s i int(10:0) inz;
  dcl-s rc int(10:0) inz;

  // create 4 threads
  for i = 1 to 4;
    workers(i).parm.num = i;
    workers(i).parm.delay = 6 - i;
    rc = pthread_create(workers(i).thread:*omit:%paddr(worker):%addr(workers(i).parm));
    if rc = 0;
      print('Main: start of worker #'+%char(workers(i).parm.num));
    else;
      print('Main: start of worker #'+%char(workers(i).parm.num)+' failed with RC='+%char(rc));
    endif;
  endfor;

  print('Main: waiting 6 seconds ...');
  sleep(6);

  // cancel 1st worker
  print('Main: cancel worker #1 RC='+%char(pthread_cancel(workers(1).thread)));
  sleep(2);

  print('Main: waiting for all workers ...');
  for i = 4 downto 1;
    print('Main: joining worker #'+%char(workers(i).parm.num)+' RC='+%char(pthread_join(workers(i).thread:*omit)));
  endfor;

  return;

  on-exit isAbnormalEnd;
    if isAbnormalEnd;
      print('Main: ending abnormally!');
    else;
      print('Main: ending normally.');
    endif;
end-proc;

//------------------------------------------------------------------------------
// thread worker procedure
//------------------------------------------------------------------------------
dcl-proc Worker;
  dcl-pi *n;
    parm_ptr pointer value;
  end-pi;

  dcl-ds parm likeds(worker_parm_t) based(parm_ptr);
  dcl-s i int(10:0) inz;
  dcl-s start timestamp(12) inz;
  dcl-s runtime packed(10:5) inz;
  dcl-s isAbnormalEnd ind inz;

  start = %timestamp(*sys:12);
  print('Worker #'+%char(parm.num)+': has thread-id '+getThreadId()+'.');
  print('Worker #'+%char(parm.num)+': setcancelstate RC='+%char(pthread_setcancelstate(PTHREAD_CANCEL_ENABLE:i)));
  print('Worker #'+%char(parm.num)+': setcanceltype RC='+%char(pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS:i)));

  for i = 1 to 5;
    print('Worker #'+%char(parm.num)+': waiting '+%char(parm.delay)+' seconds ...');
    sleep(parm.delay);
  endfor;

  return;

  on-exit isAbnormalEnd;
    runtime = %diff(%timestamp(*sys:12):start:*seconds:5);
    if isAbnormalEnd;
      print('Worker #'+%char(parm.num)+': ending abnormally after '+%char(runtime)+'s!');
    else;
      print('Worker #'+%char(parm.num)+': ending normally after '+%char(runtime)+'s.');
    endif;
end-proc;

//------------------------------------------------------------------------------
// helper procedure
//------------------------------------------------------------------------------
dcl-proc getThreadId;
  dcl-pi  *n varchar(20);
  end-pi;

  dcl-ds pthreadId likeds(pthread_id_np_t) inz;
  dcl-s buffer char(1000) inz;

  dcl-pr sprintf extproc('sprintf');
    buffer pointer value;
    templ pointer value options(*string);
    num1 uns(10:0) value;
    num2 uns(10:0) value;
    *n pointer options(*nopass);
  end-pr;

  // retrieve the thread-id
  pthreadId = pthread_getthreadid_np();

  // format the 2 parts of the thread-id in hex form
  sprintf (%addr(buffer):'%.8x:%.8x':pthreadId.intId.hi:pthreadId.intId.lo);

  // return as varchar
  return %str(%addr(buffer));
end-proc;

//------------------------------------------------------------------------------
// helper procedure
//------------------------------------------------------------------------------
dcl-proc print;
  dcl-pi  *n;
    line varchar(1000) const;
  end-pi;

  dcl-pr printf extproc('printf');
    template pointer value options(*string);
    dummy pointer options(*nopass);
  end-pr;

  // print with timestamp and "new-line"
  printf(%char(%timestamp(*sys:3))+': '+line+x'15');

  return;
end-proc; 
