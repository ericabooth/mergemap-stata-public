*! version 0.2.0  19aug2026  Eric Booth
*! _mm_rclear -- drop every run-mode global and scratch frame.  Run state is
*! deliberately kept in globals (they survive "clear all", ado-files reload
*! lazily, and the journal is appended per event), so it has to be cleared
*! explicitly at the start and end of a run.

program define _mm_rclear
    version 16
    capture macro drop MM_R_*
    capture macro drop MM_RW_*
    foreach f in _mmuk _mmmk _mmex _mmtk {
        capture frame drop `f'
    }
end
