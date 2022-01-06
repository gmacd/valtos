pub fn memset(dst: [*]u8, c: u8, n: u64) [*]u8 {
    var i: u64 = 0;
    while (i < n) : (i += 1) {
        dst[i] = c;
    }
    return dst;
}

// int
// memcmp(const void *v1, const void *v2, uint n)
// {
//   const uchar *s1, *s2;

//   s1 = v1;
//   s2 = v2;
//   while(n-- > 0){
//     if(*s1 != *s2)
//       return *s1 - *s2;
//     s1++, s2++;
//   }

//   return 0;
// }

pub fn memmove(dst: [*]u8, src: [*]u8, n: u64) [*]u8 {
    if (n == 0) {
        return dst;
    }

    var s = @ptrToInt(src);
    var d = @ptrToInt(dst);
    if ((s < d) and (s + n > d)) {
        s += n;
        d += n;
        var ntodo = n;
        while (ntodo > 0): (ntodo-=1) {
            d-=1;
            s-=1;
            @intToPtr(*u8, d).* = @intToPtr(*u8, s).*;
        }
    } else {
        var ntodo = n;
        while (ntodo > 0): (ntodo-=1) {
            @intToPtr(*u8, d).* = @intToPtr(*u8, s).*;
            d+=1;
            s+=1;
        }
    }

    return dst;
}

// // memcpy exists to placate GCC.  Use memmove.
// void*
// memcpy(void *dst, const void *src, uint n)
// {
//   return memmove(dst, src, n);
// }

// int
// strncmp(const char *p, const char *q, uint n)
// {
//   while(n > 0 && *p && *p == *q)
//     n--, p++, q++;
//   if(n == 0)
//     return 0;
//   return (uchar)*p - (uchar)*q;
// }

// char*
// strncpy(char *s, const char *t, int n)
// {
//   char *os;

//   os = s;
//   while(n-- > 0 && (*s++ = *t++) != 0)
//     ;
//   while(n-- > 0)
//     *s++ = 0;
//   return os;
// }

// // Like strncpy but guaranteed to NUL-terminate.
// char*
// safestrcpy(char *s, const char *t, int n)
// {
//   char *os;

//   os = s;
//   if(n <= 0)
//     return os;
//   while(--n > 0 && (*s++ = *t++) != 0)
//     ;
//   *s = 0;
//   return os;
// }

// int
// strlen(const char *s)
// {
//   int n;

//   for(n = 0; s[n]; n++)
//     ;
//   return n;
// }

