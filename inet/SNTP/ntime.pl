use Socket;
use Time::HiRes 'time';
use Term::ReadKey;
use constant T70,2_208_988_800;

my ($NL,%F,@B,@A)='';
&prm;
@SIG{INT,BREAK}=(sub{})x2 if $F{q};
&hlp if !@ARGV || $F{h} || $F{'?'};
&cpy if !$F{x};
$F{v}=!exists $F{v} ? 1 : $F{v}%8;
$F{r}=exists $F{r} ? 0.5 : 1 if !$F{r};
$F{dz}=$F{d} || $F{z};

if ($F{f}){
  undef $F{v};
  while (@B){
    my ($l,$b)=(shift @B,shift @B);
    $F{v}=unpack('C',substr($b,0,1)&"\x38")>>3 if !$l || !defined $F{v};
    prn($b,$l);
  }
}else{
  {
    my ($b,$b1,$l,$l1,$t,@t,$d);
    socket S,PF_INET,SOCK_DGRAM,getprotobyname 'udp';
    eval{connect S,sockaddr_in $A[1] || 123,inet_aton $A[0] || 'localhost'};
    $b=("\x03"|pack 'C',$F{v}<<3)."\0"x39 .n2t(split '\.',time+T70);
    length $b==(send(S,$b,0) || 0) ? prn($b) : err(1);
    $b='';
    recv S,$b,208,0 if &sel>0;
    $t=time+T70;
    close S;
    prn($b,1,$t) if $l=$b && 48<=length $b && length $b<=208;
    $b1=substr $b,0,1;
    $l1=$l && ($b1&"\xc0") ne "\xc0" && ($b1&"\x3f") eq ("\4"|pack 'C',$F{v}<<3);
    if (!$l1){
       if (--$F{r}){
         &err if !$l || !$F{dz};
         redo;
       }
       err(1);
    }
    @t=(t2n(substr $b,24,8),t2n(substr $b,32,8),t2n(substr $b,40,8),$t);
    $d=($t[1]-$t[0]+$t[2]-$t[3])/2;
    $t=time+$d;
    @t=((localtime $t)[0..2],int(($t-int $t)*100),int(($d-int $d)*1000));
    printf "$NL%2u:%02u:%02u".($F{s} ? '' : ",%02u (%+d)")."\n",@t[2,1,0,3,4];
  }
}
&kbd;


sub sel{
  my ($k,$p,$s)='';
  if ($p=fork){
    while (!waitpid $p,-1){
      next if $F{q} || ($k.=&kbd)!~/\x1b| |q/i;
      kill KILL,$p;
      ($k.=&kbd)=~/q/i ? exit 3: return 0;
    }
  }else{
    vec($s='',fileno(S),1)=1;
    exit select $s,undef,undef,$F{t};
  }
  $?;
}
sub hdmp{
  my ($b,$n,@h)=($_[0],0);
  while ($n<length $b){
    my ($s,@s)=(substr($b,$n,16),h4($n));
    $s=~tr/\0\7\x08\x09\x0a\x0d\xff/......./;
    push @s,h8(substr $b,$n,8),h8(length $s>8 ? substr $b,$n+8,8 : '');
    push @s,$s if !$_[1];
    push @h,join '  ',@s;
    $n+=16;
  }
  wantarray ? @h : join("\n",@h)."\n";
}
sub zoom{
  my ($b,$l,$t,@h,@a,$s)=@_;
  my ($i,$e,%v)=('  ignore',' (error)',qw(001 =1 010 =2 011 =3 100 =4));
  my %m=qw(011 =client 100 =server);
  @a=(unpack 'B8',substr $b,0,1)=~/(..)(...)(...)/;
  push @h,'0'x4 .'  '.$a[0].'.'x6 .' 'x17 .'LI'.($l && $a[0] eq '11' ? $e : '');
  push @h,' 'x6 .'..'.$a[1].'.'x3 .' 'x17 .'VN'.($v{$a[1]} || '').($l && $a[1] ne b3($F{v}) ? $e : '');
  push @h,' 'x6 .'.'x5 .$a[2].' 'x17 .'Mode'.($m{$a[2]} || '').(!$l && $a[2] ne '011' || $l && $a[2] ne '100' ? $e : '');
  @a=substr($b,1,47)=~/^(.)(.)(.)(..)(..)(.{4})(.{4})(.{8})(.{8})(.{8})(.{8})/s;
  if (!$l){
    push @h,h4(1).'  '.h8(join('',@a[0..4]),1);
    push @h,h4(8).'  '.h8(join('',@a[5,6]));
    push @h,h4(8*($_-5)).'  '.h8($a[$_]) for 7..9;
    push @h,h4(40).'  '.h8($a[10]).'  T1='.t2n($a[10]);
  }else{
    $s=unpack 'C',$a[0];
    push @h,h4(1).'  '.h8($a[0])."  Stratum=$s".($s<1 || 14<$s ? $e : '');
    push @h,h4((2,3,4,6,8,12,16)[$_-1]).'  '.h8($a[$_]).$i for 1..7;
    push @h,h4(8*($_+2)).'  '.h8($a[$_+7])."  T$_=".t2n($a[$_+7]) for 1..3;
  }
  push @h,hdmp(substr($b,48),1);
  push @h,' 'x31 ."T4=$t" if $t;
  join("\n",@h)."\n";
}
sub t2n{
  my ($t,$m)=(unpack('N',substr $_[0],0,4),unpack 'B32',substr $_[0],4,4);
  $m=~s/(.*?)(0*)$/$2$1/;
  $t.'.'.unpack 'N',pack 'B32',$m;
}
sub n2t{
  pack('N',$_[0]).pack 'N',$_[1]<<31-int($_[1] ? log($_[1])/log 2 : 0);
}
sub h8{
  my $s=join ' ',unpack 'H2'x8,$_[0];
  uc $s.(!$_[1] ? ' 'x(23-length $s) : '');
}
sub h4{
  uc sprintf "%04x",$_[0];
}
sub b3{
  substr ''.(unpack 'B8',pack 'C',$_[0]),5,3;
}
sub kbd{
  my ($s,$c);
  $s.=$c while $c=ReadKey -1;
  $s || '';
}
sub nl1{
  return if !$F{dz};
  print $NL;
  $NL="\n";
}
sub err{
  &nl1;
  print ":(\n" if !$F{s} || $F{dz};
  exit 1 if $_[0];
}
sub prn{
  &nl1;
  print $F{d} ? ''.hdmp($_[0]) : zoom(@_) if $F{dz};
  return if !$F{b};
  print STDERR ($_[1] ? 1 : 0).' '.length($_[0])."\n";
  binmode STDERR;
  print STDERR $_[0];
  binmode STDERR,':crlf';
  print STDERR "\n";
}
sub chn{
  my ($b,$n,@a)=shift;
  while (length $b){
    last if $b!~/^(0|1) (\d+)\r?\x0a/ || length $b<($n=length($&)+$2);
    push @a,$1,substr($b,length $&,$2);
    last if !($b=~s/^.{$n}\r?\x0a//s);
  }
  @a;
}
sub cpy{
  print<<EOC;
Copyright (C) 1998-2006 Suncloud.Ru
Max Baklanovsky <baklanovsky\@mail.ru>

EOC
}
sub hlp{
  cpy if !$F{x};
  print<<EOH;
Usage: ntime [-xvNstNrNdzbqh] [-ffile] [sntp]
 x   - w/o (C)
 vN  - ver N (1 by default)
 s   - short format (for time)
 tN  - timeout N (1 w/o N) sec
 rN  - N attempts if no|bad ans
 d|z - hex dump|zoom (detail)
 b   - bin output to stderr
 f   - bin input (w/o sntp)
 q   - w/o q,esc,cbreak
 h   - (or ?) help only
EOH
  exit;
}
sub prm{
  my (%x,@a)=qw(d z z d);
  for (@ARGV){
    if (/^-/){
      $F{'?'}=1 if s/\?//g;
      @a=/^-([^f]*)f?(.*)$/i;
      @F{$_,$x{$_} || ''}=1 for split '',lc $a[0];
      $F{v}=0+$1 if $a[0]=~/v(\d+)[^v]*$/i;
      $F{t}=0+$1 if $a[0]=~/t(\d+)[^t]*$/i;
      $F{r}=0+$1 if $a[0]=~/r(\d*)[^r]*$/i;
      next if !$a[1];
      $F{f}=1;
      if (open F,$a[1]){
        binmode F;
        @B=chn join '',<F>;
        close F;
      }
    }else{
      @A=split ':',$_ if !@A;
    }
  }
}