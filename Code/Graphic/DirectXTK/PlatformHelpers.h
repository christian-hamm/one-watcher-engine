/* 
 * ============================================================
 * Copyright (C) Christian Hamm. All Rights Reserved.
 * ============================================================
 */

#pragma once

#pragma warning(disable : 4324 4481)

#include <exception>
#include <memory>


namespace DirectX
{
    // Helper class for COM exceptions
    class com_exception : public std::exception
    {
    public:
        com_exception(HRESULT hr) : result(hr) {}

        virtual const char* what() const override
        {
            static char s_str[64] = { 0 };
            sprintf_s(s_str, "Failure with HRESULT of %08X", result);
            return s_str;
        }

    private:
        HRESULT result;
    };

    // Helper utility converts D3D API failures into exceptions.
    inline void ThrowIfFailed(HRESULT hr)
    {
        if (FAILED(hr))
        {
            throw com_exception(hr);
        }
    }


    // Helper for output debug tracing
    inline void DebugTrace( _In_z_ _Printf_format_string_ const char* format, ... )
    {
#ifdef _DEBUG
        va_list args;
        va_start( args, format );

        char buff[1024]={0};
        vsprintf_s( buff, format, args );
        OutputDebugStringA( buff );
        va_end( args );
#else
        UNREFERENCED_PARAMETER( format );
#endif
    }


    // Helper smart-pointers
#if (_WIN32_WINNT >= _WIN32_WINNT_WIN10) || (defined(_XBOX_ONE) && defined(_TITLE)) || !defined(WINAPI_FAMILY) || (WINAPI_FAMILY == WINAPI_FAMILY_DESKTOP_APP)
    struct virtual_deleter { void operator()(void* p) { if (p) VirtualFree(p, 0, MEM_RELEASE); } };
#endif

    struct aligned_deleter { void operator()(void* p) { _aligned_free(p); } };

    struct handle_closer { void operator()(HANDLE h) { if (h) CloseHandle(h); } };

    typedef public std::unique_ptr<void, handle_closer> ScopedHandle;

    inline HANDLE safe_handle( HANDLE h ) { return (h == INVALID_HANDLE_VALUE) ? 0 : h; }
}


#if (defined(_MSC_VER) && (_MSC_VER < 1610)) || defined(DIRECTX_EMULATE_MUTEX)

// Emulate the C++0x mutex and lock_guard types when building with Visual Studio versions < 2012.
namespace std
{
    class mutex
    {
    public:
        mutex()         { InitializeCriticalSection(&mCriticalSection); }
        ~mutex()        { DeleteCriticalSection(&mCriticalSection); }

        void lock()     { EnterCriticalSection(&mCriticalSection); }
        void unlock()   { LeaveCriticalSection(&mCriticalSection); }
        bool try_lock() { return TryEnterCriticalSection(&mCriticalSection) != 0; }

    private:
        CRITICAL_SECTION mCriticalSection;

        mutex(mutex const&);
        mutex& operator= (mutex const&);
    };


    template<typename Mutex>
    class lock_guard
    {
    public:
        typedef Mutex mutex_type;

        explicit lock_guard(mutex_type& mutex)
          : mMutex(mutex)
        {
            mMutex.lock();
        }

        ~lock_guard()
        {
            mMutex.unlock();
        }

    private:
        mutex_type& mMutex;

        lock_guard(lock_guard const&);
        lock_guard& operator= (lock_guard const&);
    };
}

#else   // _MSC_VER < 1610

#include <mutex>

#endif
