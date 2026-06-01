import pygame
import sys

# Configurações iniciais
def main():
    pygame.init()
    largura, altura = 800, 600
    tela = pygame.display.set_mode((largura, altura))
    pygame.display.set_caption("As Aventuras da Helena")
    relogio = pygame.time.Clock()

    # Cores
    verde_claro = (132, 199, 97)
    verde_escuro = (28, 79, 41)
    branco = (255, 255, 255)
    amarelo = (255, 221, 85)
    rosa = (235, 107, 153)
    azul = (97, 183, 255)
    marrom = (115, 74, 18)

    fonte_titulo = pygame.font.SysFont(None, 64)
    fonte_botao = pygame.font.SysFont(None, 36)
    fonte_mensagem = pygame.font.SysFont(None, 40)

    # Estados do jogo
    em_intro = True
    jogo_ativo = False
    vitoria = False
    game_over = False

    # Helena
    personagem = pygame.Rect(80, altura - 140, 48, 64)
    velocidade = 5
    pos_inicial_personagem = (80, altura - 140)

    # Saída da fase
    saida = pygame.Rect(largura - 120, 40, 100, 80)

    # Obstáculos / animais
    animais_iniciais = [
        pygame.Rect(240, 180, 70, 50),
        pygame.Rect(420, 320, 70, 50),
        pygame.Rect(600, 220, 70, 50),
        pygame.Rect(310, 450, 70, 50),
    ]

    cores_animais = [
        (255, 143, 83),
        (141, 207, 166),
        (223, 156, 255),
        (255, 218, 121),
    ]
    cores_ornamentos = [
        (255, 255, 255),
        (80, 51, 107),
        (45, 96, 125),
        (133, 76, 42),
    ]

    movimentos_iniciais = [2, -3, 2, -2]
    animais = [animal.copy() for animal in animais_iniciais]
    movimentos = movimentos_iniciais.copy()

    def reiniciar_fase():
        personagem.topleft = pos_inicial_personagem
        for i, animal in enumerate(animais):
            animal.topleft = animais_iniciais[i].topleft
            movimentos[i] = movimentos_iniciais[i]

    while True:
        for evento in pygame.event.get():
            if evento.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if evento.type == pygame.MOUSEBUTTONDOWN:
                x, y = evento.pos
                if em_intro:
                    if 260 <= x <= 540 and 340 <= y <= 400:
                        jogo_ativo = True
                        em_intro = False
                        vitoria = False
                        game_over = False
                        reiniciar_fase()
                    if 260 <= x <= 540 and 420 <= y <= 475:
                        pygame.quit()
                        sys.exit()
                elif vitoria or game_over:
                    em_intro = True
                    vitoria = False
                    game_over = False

        if em_intro:
            tela.fill(verde_claro)
            desenhar_intro(tela, fonte_titulo, fonte_botao, branco, rosa, azul, marrom)

        elif jogo_ativo:
            teclas = pygame.key.get_pressed()
            if teclas[pygame.K_LEFT] or teclas[pygame.K_a]:
                personagem.x -= velocidade
            if teclas[pygame.K_RIGHT] or teclas[pygame.K_d]:
                personagem.x += velocidade
            if teclas[pygame.K_UP] or teclas[pygame.K_w]:
                personagem.y -= velocidade
            if teclas[pygame.K_DOWN] or teclas[pygame.K_s]:
                personagem.y += velocidade

            personagem.clamp_ip(pygame.Rect(0, 0, largura, altura))

            tela.fill(verde_claro)
            desenhar_cenario(tela, largura, altura, verde_escuro, amarelo, branco)
            desenhar_saida(tela, saida, azul, branco)
            desenhar_personagem(tela, personagem, rosa, branco)
            desenhar_animais(tela, animais, cores_animais, cores_ornamentos)

            for i, animal in enumerate(animais):
                animal.x += movimentos[i]
                if animal.left < 100 or animal.right > largura - 100:
                    movimentos[i] = -movimentos[i]
                    animal.x += movimentos[i] * 2

            if personagem.colliderect(saida):
                jogo_ativo = False
                vitoria = True

            for animal in animais:
                if personagem.colliderect(animal):
                    jogo_ativo = False
                    game_over = True

        else:
            tela.fill(verde_claro)
            desenhar_cenario(tela, largura, altura, verde_escuro, amarelo, branco)
            if vitoria:
                mensagem = fonte_mensagem.render("Parabéns! Helena alcançou a saída.", True, azul)
            else:
                mensagem = fonte_mensagem.render("Ops! Um animal encostou na Helena.", True, azul)
            instrucoes = fonte_mensagem.render("Clique para voltar ao menu principal.", True, azul)
            tela.blit(mensagem, (60, 250))
            tela.blit(instrucoes, (120, 310))

        pygame.display.flip()
        relogio.tick(60)


def desenhar_intro(tela, fonte_titulo, fonte_botao, cor_texto, cor_botao, cor_ombra, cor_tronco):
    tela.fill((24, 92, 52))
    titulo = fonte_titulo.render("As Aventuras da Helena", True, cor_texto)
    subtitulo = fonte_botao.render("Tema da floresta com animais divertidos", True, cor_texto)

    pygame.draw.rect(tela, cor_botao, (260, 340, 280, 60), border_radius=12)
    pygame.draw.rect(tela, cor_botao, (260, 420, 280, 55), border_radius=12)
    botoes_texto = fonte_botao.render("Start", True, (0, 0, 0))
    botoes_sair = fonte_botao.render("Exit", True, (0, 0, 0))

    pygame.draw.circle(tela, cor_tronco, (150, 120), 60)
    pygame.draw.rect(tela, cor_tronco, (140, 120, 20, 160), border_radius=10)
    pygame.draw.circle(tela, cor_ombra, (140, 90), 45)
    pygame.draw.circle(tela, cor_ombra, (180, 90), 45)

    tela.blit(titulo, (80, 120))
    tela.blit(subtitulo, (140, 200))
    tela.blit(botoes_texto, (360, 350))
    tela.blit(botoes_sair, (360, 425))


def desenhar_cenario(tela, largura, altura, cor_solo, cor_sol, cor_nuvem):
    pygame.draw.rect(tela, cor_solo, (0, altura - 120, largura, 120))
    pygame.draw.circle(tela, cor_sol, (700, 90), 35)
    pygame.draw.circle(tela, cor_nuvem, (120, 90), 30)
    pygame.draw.circle(tela, cor_nuvem, (150, 80), 35)
    pygame.draw.circle(tela, cor_nuvem, (180, 100), 28)
    for x in range(0, largura, 120):
        pygame.draw.polygon(tela, cor_solo, [(x + 20, altura - 120), (x + 60, altura - 180), (x + 100, altura - 120)])


def desenhar_saida(tela, saida, cor, cor_texto):
    pygame.draw.rect(tela, cor, saida, border_radius=12)
    texto_saida = pygame.font.SysFont(None, 24).render("SAÍDA", True, cor_texto)
    tela.blit(texto_saida, (saida.x + 10, saida.y + 25))


def desenhar_personagem(tela, personagem, cor_rosto, cor_detalhe):
    cabeça = pygame.Rect(personagem.x + 4, personagem.y - 16, personagem.width - 8, 32)
    corpo = pygame.Rect(personagem.x, personagem.y + 10, personagem.width, personagem.height - 10)

    # Cabelo e roupas da menina
    cor_cabelo = (115, 70, 160)
    pygame.draw.ellipse(tela, cor_cabelo, (cabeça.x - 4, cabeça.y - 10, cabeça.width + 8, cabeça.height + 12))
    pygame.draw.rect(tela, cor_rosto, corpo, border_radius=14)
    saia = pygame.Rect(personagem.x, corpo.bottom - 14, personagem.width, 22)
    pygame.draw.rect(tela, (255, 163, 213), saia, border_radius=12)
    faixa = pygame.Rect(personagem.x + 6, corpo.y + 10, personagem.width - 12, 8)
    pygame.draw.rect(tela, (255, 255, 255), faixa, border_radius=6)

    # Rosto com olhos grandes e bochechas rosadas
    pygame.draw.ellipse(tela, cor_rosto, cabeça)
    pygame.draw.circle(tela, (255, 255, 255), (cabeça.x + 10, cabeça.y + 16), 6)
    pygame.draw.circle(tela, (255, 255, 255), (cabeça.right - 10, cabeça.y + 16), 6)
    pygame.draw.circle(tela, (0, 0, 0), (cabeça.x + 10, cabeça.y + 16), 2)
    pygame.draw.circle(tela, (0, 0, 0), (cabeça.right - 10, cabeça.y + 16), 2)
    pygame.draw.circle(tela, (255, 190, 200), (cabeça.x + 6, cabeça.y + 22), 4)
    pygame.draw.circle(tela, (255, 190, 200), (cabeça.right - 6, cabeça.y + 22), 4)
    pygame.draw.arc(tela, (0, 0, 0), (cabeça.x + 8, cabeça.y + 18, cabeça.width - 16, 18), 3.2, 0.1, 2)

    # Braços infantis
    pygame.draw.line(tela, cor_rosto, (personagem.x - 4, corpo.y + 16), (personagem.x + 8, corpo.y + 22), 6)
    pygame.draw.line(tela, cor_rosto, (personagem.right + 4, corpo.y + 16), (personagem.right - 8, corpo.y + 22), 6)

    # Pernas e sapatinhos
    perna_esquerda = pygame.Rect(personagem.x + 12, saia.bottom - 2, 10, 24)
    perna_direita = pygame.Rect(personagem.right - 22, saia.bottom - 2, 10, 24)
    pygame.draw.rect(tela, (255, 233, 210), perna_esquerda, border_radius=5)
    pygame.draw.rect(tela, (255, 233, 210), perna_direita, border_radius=5)
    pygame.draw.rect(tela, (120, 60, 150), (personagem.x + 8, saia.bottom + 18, 12, 6), border_radius=3)
    pygame.draw.rect(tela, (120, 60, 150), (personagem.right - 20, saia.bottom + 18, 12, 6), border_radius=3)


def desenhar_animais(tela, animais, cores, cores_ornamentos):
    for i, animal in enumerate(animais):
        cor_corpo = cores[i % len(cores)]
        cor_ornamento = cores_ornamentos[i % len(cores_ornamentos)]
        corpo = animal.inflate(10, 10)
        pygame.draw.ellipse(tela, cor_corpo, corpo)

        # Cabeça
        cabeca = pygame.Rect(animal.right - 18, animal.y - 10, 30, 28)
        pygame.draw.ellipse(tela, cor_corpo, cabeca)

        # Olhos
        pygame.draw.circle(tela, (255, 255, 255), (cabeca.x + 8, cabeca.y + 12), 6)
        pygame.draw.circle(tela, (255, 255, 255), (cabeca.x + 22, cabeca.y + 12), 6)
        pygame.draw.circle(tela, (0, 0, 0), (cabeca.x + 8, cabeca.y + 12), 3)
        pygame.draw.circle(tela, (0, 0, 0), (cabeca.x + 22, cabeca.y + 12), 3)

        # Detalhes do corpo
        for j, offset in enumerate([(-15, 8), (0, 10), (18, 6)]):
            pygame.draw.circle(tela, cor_ornamento, (animal.x + animal.width // 2 + offset[0], animal.y + offset[1]), 7)

        # Pernas
        pygame.draw.line(tela, cor_ornamento, (animal.x + 10, animal.bottom), (animal.x + 10, animal.bottom + 14), 5)
        pygame.draw.line(tela, cor_ornamento, (animal.x + 30, animal.bottom), (animal.x + 30, animal.bottom + 14), 5)
        pygame.draw.line(tela, cor_ornamento, (animal.x + 50, animal.bottom), (animal.x + 50, animal.bottom + 14), 5)

        # Cauda
        pygame.draw.polygon(tela, cor_corpo, [
            (animal.x + 5, animal.y + 10),
            (animal.x - 15, animal.y + 5),
            (animal.x - 10, animal.y + 20),
        ])

if __name__ == "__main__":
    main()
